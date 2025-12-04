import json
import boto3
import os
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
from html import unescape

def lambda_handler(event, context):
    """
    Fetch AWS services available in a target region from SSM Parameter Store
    and return news/announcements about the region.
    Configure via TARGET_REGION and SSM_REGION environment variables.
    """
    # Handle CORS preflight requests (Lambda Function URL handles CORS automatically)
    http_method = event.get('requestContext', {}).get('http', {}).get('method') or event.get('httpMethod', 'GET')
    if http_method == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': ''
        }

    try:
        # Target region to query services for (configurable via TARGET_REGION env var)
        target_region = os.environ.get('TARGET_REGION', 'us-east-1')
        # SSM global infrastructure parameters are always stored in us-east-1 for all regions
        ssm_client = boto3.client('ssm', region_name='us-east-1')

        # Get all services available ONLY in the target region
        services = []
        try:
            # Query path for services available in the specific target region
            path = f'/aws/service/global-infrastructure/regions/{target_region}/services'
            print(f"Querying SSM (us-east-1) for path: {path}")

            # Use paginator to get all parameters
            paginator = ssm_client.get_paginator('get_parameters_by_path')
            page_iterator = paginator.paginate(
                Path=path,
                Recursive=True,
                MaxResults=10  # SSM Parameter Store maximum is 10
            )

            # Extract service names from parameter names
            # Parameter names are like: /aws/service/global-infrastructure/regions/{target_region}/services/{service_name}
            # This path ensures we only get services available in the target region
            for page in page_iterator:
                params = page.get('Parameters', [])
                for param in params:
                    param_name = param.get('Name', '')
                    # Verify the parameter is for the correct region
                    if target_region in param_name:
                        # Extract service name from path (last segment after /services/)
                        parts = param_name.split('/')
                        if len(parts) > 0:
                            service_name = parts[-1]
                            if service_name and service_name not in services:
                                services.append(service_name)

            print(f"Found {len(services)} services for region {target_region}")
        except Exception as e:
            # Log error for debugging
            error_msg = f"Error fetching services for {target_region} from SSM: {str(e)}"
            import traceback
            print(error_msg)
            traceback.print_exc()
            # Return error in response so frontend can display it
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Cache-Control': 'no-cache'  # Don't cache errors
                },
                'body': json.dumps({
                    'region': target_region,
                    'services': [],
                    'count': 0,
                    'error': error_msg
                })
            }

        # Sort services alphabetically
        services.sort()

        # Fetch recent AWS announcements from RSS feed
        news = []
        try:
            # AWS What's New RSS feed
            rss_url = 'https://aws.amazon.com/about-aws/whats-new/recent/feed/'

            # Fetch RSS feed
            req = urllib.request.Request(
                rss_url,
                headers={
                    'User-Agent': 'Mozilla/5.0 (compatible; AWS-Lambda)'
                }
            )

            with urllib.request.urlopen(req, timeout=5) as response:
                rss_content = response.read().decode('utf-8')
                root = ET.fromstring(rss_content)

            # Parse RSS items (limit to 5 most recent)
            items = root.findall('.//item')[:5]

            for item in items:
                title_elem = item.find('title')
                description_elem = item.find('description')
                pub_date_elem = item.find('pubDate')
                link_elem = item.find('link')

                if title_elem is not None:
                    title = unescape(title_elem.text or '')
                    description = ''
                    if description_elem is not None:
                        # Extract text from HTML description
                        desc_text = unescape(description_elem.text or '')
                        # Remove HTML tags and truncate
                        import re
                        desc_text = re.sub(r'<[^>]+>', '', desc_text)
                        description = desc_text[:300] + '...' if len(desc_text) > 300 else desc_text

                    # Parse date
                    date_str = datetime.now().strftime('%Y-%m-%d')
                    if pub_date_elem is not None:
                        try:
                            from email.utils import parsedate_to_datetime
                            pub_date = parsedate_to_datetime(pub_date_elem.text)
                            date_str = pub_date.strftime('%Y-%m-%d')
                        except:
                            pass

                    news.append({
                        'title': title,
                        'content': description,
                        'date': date_str,
                        'type': 'announcement',
                        'link': link_elem.text if link_elem is not None else ''
                    })
        except Exception as e:
            # Silently fallback to default news if RSS fetch fails (don't log to reduce latency)
            # Fallback to default news if RSS fetch fails
            news = [
                {
                    'title': 'New Region Launch',
                    'content': 'Asia Pacific (New Zealand) - ap-southeast-6 is now available! This region brings AWS services closer to New Zealand customers, reducing latency and enabling data residency requirements.',
                    'date': '2024-12-04',
                    'type': 'announcement'
                },
                {
                    'title': 'Planned Services',
                    'content': 'AWS continues to expand service availability in ap-southeast-6. Additional services are being added regularly. Check back for updates on new service launches!',
                    'date': '2024-12-04',
                    'type': 'update'
                },
                {
                    'title': 'Meetup Event',
                    'content': 'AWS Wellington User Group Meetup #77 - December 9, 2025 at The Green Man Pub, Wellington. Join us to learn about the new region and win prizes from Ingram Micro!',
                    'date': '2024-12-04',
                    'type': 'event'
                }
            ]

        # Prepare response data
        response_data = {
            'region': target_region,
            'services': services,
            'count': len(services),
            'news': news,
            'timestamp': context.aws_request_id if context else 'unknown'
        }

        # Calculate ETag for cache validation (hash of the response data)
        import hashlib
        response_json = json.dumps(response_data, sort_keys=True)
        etag = hashlib.md5(response_json.encode()).hexdigest()

        # Check if client has cached version (If-None-Match header)
        if_match = event.get('headers', {}).get('if-none-match') or event.get('headers', {}).get('If-None-Match')
        if if_match and if_match.strip('"') == etag:
            # Client has cached version, return 304 Not Modified
            return {
                'statusCode': 304,
                'headers': {
                    'ETag': f'"{etag}"',
                    'Cache-Control': 'public, max-age=300, stale-while-revalidate=600'  # Match 200 response cache policy
                },
                'body': ''
            }

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Cache-Control': 'public, max-age=300, stale-while-revalidate=600',  # Cache 5min, serve stale up to 10min while revalidating
                'ETag': f'"{etag}"'
            },
            'body': response_json
        }
    except Exception as e:
        import traceback
        error_details = {
            'error': str(e),
            'message': 'Failed to fetch data',
            'type': type(e).__name__
        }
        # Include traceback in response for debugging (remove in production)
        if os.environ.get('DEBUG', 'false').lower() == 'true':
            error_details['traceback'] = traceback.format_exc()

        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Cache-Control': 'no-cache'  # Don't cache errors
            },
            'body': json.dumps(error_details)
        }
