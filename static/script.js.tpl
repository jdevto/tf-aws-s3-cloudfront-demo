// API endpoint via CloudFront (cached) - injected by Terraform
const API_ENDPOINT = '${cloudfront_url}/api/services';

// Global variables for icons data and search
let iconsData = [];
let iconMap = {}; // Direct mapping: service name -> icon info
let allServices = [];
let filteredServices = [];

async function loadIconsData() {
    try {
        const response = await fetch('/icons.json');
        if (response.ok) {
            iconsData = await response.json();

            // Build icon map from icons.json - simple direct lookup by service name
            iconsData.forEach(icon => {
                const path = icon.path || '';
                const normalizedPath = path.replace('icons/', '/icons/');
                const serviceName = icon.name; // Short service name from API
                const fullname = icon.fullname || ''; // Full display name
                const description = icon.description || '';
                const category = icon.category || 'general';
                const tags = icon.tags || [];

                // Map by service name (direct lookup - this is the primary mapping)
                if (serviceName) {
                    iconMap[serviceName] = {
                        path: normalizedPath,
                        category: category,
                        description: description,
                        tags: tags,
                        name: fullname
                    };
                }
            });

            console.log(`Loaded $${iconsData.length} icons, created $${Object.keys(iconMap).length} service mappings`);
        }
    } catch (error) {
        console.warn('Failed to load icons.json:', error);
    }
}

function getServiceIconInfo(serviceName) {
    const normalized = serviceName.toLowerCase().replace(/_/g, '-');

    // Direct lookup by service name (from icons.json name field)
    if (iconMap[normalized]) {
        return iconMap[normalized];
    }


    // Fallback: generic AWS icon
    return {
        path: '/icons/aws-generic.svg',
        category: 'general',
        description: 'AWS Service',
        tags: [],
        name: 'AWS'
    };
}

function filterServices(searchTerm) {
    if (!searchTerm || searchTerm.trim() === '') {
        filteredServices = [...allServices];
        return;
    }

    const searchLower = searchTerm.toLowerCase().trim();
    filteredServices = allServices.filter(service => {
        const serviceLower = service.toLowerCase();

        // Match service name
        if (serviceLower.includes(searchLower)) {
            return true;
        }

        // Match icon info
        const iconInfo = getServiceIconInfo(service);
        if (iconInfo) {
            // Match description
            if (iconInfo.description && iconInfo.description.toLowerCase().includes(searchLower)) {
                return true;
            }

            // Match tags
            if (iconInfo.tags && iconInfo.tags.some(tag =>
                tag.toLowerCase().includes(searchLower)
            )) {
                return true;
            }

            // Match name
            if (iconInfo.name && iconInfo.name.toLowerCase().includes(searchLower)) {
                return true;
            }
        }

        return false;
    });
}

function renderServices() {
    const servicesContainer = document.getElementById('services-container');
    if (!servicesContainer) return;

    servicesContainer.innerHTML = '';

    if (filteredServices.length === 0) {
        servicesContainer.innerHTML = '<p style="text-align: center; color: var(--text-light);">No services found matching your search.</p>';
        return;
    }

    filteredServices.forEach(service => {
        const card = document.createElement('div');
        card.className = 'service-card';
        const iconInfo = getServiceIconInfo(service);
        const iconUrl = iconInfo.path;

        // Use fullname for display, fallback to service name if fullname not available
        const displayName = iconInfo.name || service;

        // Build card content (no description inline - it will be in tooltip)
        let cardContent = '<img src="' + iconUrl + '" alt="' + service + '" class="service-icon" loading="lazy" onerror="this.onerror=null; this.src=\'/icons/aws-generic.svg\';">';
        cardContent += '<div class="service-label">' + displayName + '</div>';

        card.innerHTML = cardContent;

        // Add tooltip if description is available
        if (iconInfo.description) {
            const tooltip = document.createElement('div');
            tooltip.className = 'service-tooltip';
            tooltip.innerHTML = '<div class="tooltip-title">' + displayName + '</div>' +
                               '<div class="tooltip-description">' + iconInfo.description + '</div>';
            // Append to body instead of card to avoid positioning issues
            document.body.appendChild(tooltip);

            // Show tooltip on hover
            let hoverTimeout;
            card.addEventListener('mouseenter', function() {
                clearTimeout(hoverTimeout);
                hoverTimeout = setTimeout(function() {
                    tooltip.classList.add('visible');
                    positionTooltip(card, tooltip);
                }, 100); // Small delay to prevent flickering
            });

            card.addEventListener('mouseleave', function() {
                clearTimeout(hoverTimeout);
                tooltip.classList.remove('visible');
            });

            // Also hide on tooltip mouseleave
            tooltip.addEventListener('mouseenter', function() {
                clearTimeout(hoverTimeout);
            });

            tooltip.addEventListener('mouseleave', function() {
                tooltip.classList.remove('visible');
            });

            // Reposition on window resize and scroll
            function repositionTooltip() {
                if (tooltip.classList.contains('visible')) {
                    positionTooltip(card, tooltip);
                }
            }

            window.addEventListener('resize', repositionTooltip);
            window.addEventListener('scroll', repositionTooltip, true);
        }

        servicesContainer.appendChild(card);
    });

    // Update count
    const existingCount = servicesContainer.parentNode.querySelector('.service-count');
    if (existingCount) {
        existingCount.remove();
    }

    const countInfo = document.createElement('p');
    countInfo.className = 'service-count';
    countInfo.style.textAlign = 'center';
    countInfo.style.marginTop = '1rem';
    countInfo.style.color = 'var(--text-light)';
    countInfo.textContent = `Showing $${filteredServices.length} of $${allServices.length} services`;
    servicesContainer.parentNode.insertBefore(countInfo, servicesContainer.nextSibling);
}

async function fetchData() {
    const servicesContainer = document.getElementById('services-container');
    const servicesLoading = document.getElementById('loading');
    const servicesError = document.getElementById('error-message');
    const newsContainer = document.getElementById('news-container');
    const newsLoading = document.getElementById('news-loading');
    const newsError = document.getElementById('news-error');

    if (!API_ENDPOINT) {
        if (servicesLoading) {
            servicesLoading.textContent = 'API endpoint not configured';
            servicesLoading.style.color = 'red';
        }
        if (newsLoading) {
            newsLoading.textContent = 'API endpoint not configured';
            newsLoading.style.color = 'red';
        }
        return;
    }

    try {
        // Load icons data first
        await loadIconsData();

        // Retry logic for transient errors
        let lastError = null;
        let data = null;
        const maxRetries = 3;

        for (let attempt = 1; attempt <= maxRetries; attempt++) {
            try {
                const response = await fetch(API_ENDPOINT, {
                    method: 'GET',
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });

                if (!response.ok) {
                    // Retry on 5xx errors, fail immediately on 4xx
                    if (response.status >= 500 && attempt < maxRetries) {
                        await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
                        continue;
                    }
                    throw new Error('HTTP error! status: ' + response.status);
                }

                data = await response.json();
                lastError = null;
                break;
            } catch (error) {
                lastError = error;
                if (attempt < maxRetries && error.message.includes('502')) {
                    await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
                    continue;
                }
                throw error;
            }
        }

        if (!data) {
            throw lastError || new Error('Failed to fetch data after retries');
        }

        // Hide loading messages
        if (servicesLoading) servicesLoading.style.display = 'none';
        if (servicesError) servicesError.style.display = 'none';
        if (newsLoading) newsLoading.style.display = 'none';
        if (newsError) newsError.style.display = 'none';

        // Store all services and initialize filtered
        if (data && data.services && data.services.length > 0) {
            allServices = data.services;

            // Sort services by fullname (display name) instead of short service name
            allServices.sort((a, b) => {
                const fullnameA = (getServiceIconInfo(a).name || a).toLowerCase();
                const fullnameB = (getServiceIconInfo(b).name || b).toLowerCase();
                return fullnameA.localeCompare(fullnameB);
            });

            filteredServices = [...allServices];
            renderServices();
        } else if (servicesContainer) {
            servicesContainer.innerHTML = '<p>No services found</p>';
        }

        // Display news
        if (data && data.news && data.news.length > 0 && newsContainer) {
            newsContainer.innerHTML = '';
            data.news.forEach(function(item) {
                const card = document.createElement('div');
                card.className = 'news-card';
                const typeIcon = item.type === 'event' ? '🎉' : item.type === 'update' ? '🔄' : '📢';
                card.innerHTML = '<h3>' + typeIcon + ' ' + item.title + '</h3>' +
                    '<p>' + item.content + '</p>' +
                    (item.date ? '<p style="font-size: 0.9em; color: var(--text-light); margin-top: 0.5rem;">Date: ' + item.date + '</p>' : '');
                newsContainer.appendChild(card);
            });
        } else if (newsContainer) {
            newsContainer.innerHTML = '<p>No news available</p>';
        }
    } catch (error) {
        console.error('Error fetching data:', error);
        if (servicesLoading) servicesLoading.style.display = 'none';
        if (servicesError) {
            servicesError.style.display = 'block';
            servicesError.textContent = 'Error: ' + error.message + '. Please check the Lambda Function URL configuration.';
        }
        if (newsLoading) newsLoading.style.display = 'none';
        if (newsError) {
            newsError.style.display = 'block';
            newsError.textContent = 'Error: ' + error.message + '. Please check the Lambda Function URL configuration.';
        }
    }
}

// Position tooltip relative to service card (above the card by default)
function positionTooltip(card, tooltip) {
    // Get card position relative to viewport
    const cardRect = card.getBoundingClientRect();
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    const scrollX = window.pageXOffset || document.documentElement.scrollLeft;
    const scrollY = window.pageYOffset || document.documentElement.scrollTop;

    // Calculate tooltip dimensions (need to make it visible temporarily)
    tooltip.style.visibility = 'hidden';
    tooltip.style.display = 'block';
    tooltip.style.position = 'fixed';
    const tooltipRect = tooltip.getBoundingClientRect();
    const tooltipWidth = tooltipRect.width;
    const tooltipHeight = tooltipRect.height;
    tooltip.style.visibility = 'visible';

    // Default: position above the card, horizontally centered
    let left = cardRect.left + (cardRect.width / 2) - (tooltipWidth / 2); // Center horizontally
    let top = cardRect.top - tooltipHeight - 10; // 10px gap above card

    // If tooltip would overflow top of viewport, position below card
    if (top < 10) {
        top = cardRect.bottom + 10; // 10px gap below card
    }

    // If tooltip would overflow bottom of viewport, position above but adjust
    if (top + tooltipHeight > viewportHeight - 10) {
        top = Math.max(10, cardRect.top - tooltipHeight - 10);
    }

    // Ensure tooltip doesn't go off screen horizontally
    if (left < 10) {
        left = 10;
    }
    if (left + tooltipWidth > viewportWidth - 10) {
        left = viewportWidth - tooltipWidth - 10;
    }

    // If card is too narrow and tooltip is wider, align to card edges
    if (tooltipWidth > cardRect.width) {
        // Center on card, but ensure it doesn't overflow viewport
        left = cardRect.left + (cardRect.width / 2) - (tooltipWidth / 2);
        if (left < 10) {
            left = 10;
        }
        if (left + tooltipWidth > viewportWidth - 10) {
            left = viewportWidth - tooltipWidth - 10;
        }
    }

    tooltip.style.position = 'fixed';
    tooltip.style.left = left + 'px';
    tooltip.style.top = top + 'px';
    tooltip.style.display = 'block';
    tooltip.style.zIndex = '10000'; // Ensure it's above everything
}

// Setup search functionality
function setupSearch() {
    const searchInput = document.getElementById('search-input');
    if (searchInput) {
        searchInput.addEventListener('input', function(e) {
            filterServices(e.target.value);
            renderServices();
        });
    }
}

// Setup tab navigation
function setupTabs() {
    const tabLinks = document.querySelectorAll('.tab-link');
    const tabContents = document.querySelectorAll('.tab-content');

    tabLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();

            const targetTab = this.getAttribute('data-tab');

            // Remove active class from all tabs and links
            tabLinks.forEach(l => l.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));

            // Add active class to clicked tab
            this.classList.add('active');
            const targetContent = document.getElementById(targetTab + '-tab');
            if (targetContent) {
                targetContent.classList.add('active');
            }

            // Scroll to top of main content, accounting for sticky header and nav
            const main = document.querySelector('main');
            const header = document.querySelector('header');
            const nav = document.querySelector('.top-nav');

            if (main) {
                // Calculate heights of sticky elements
                const headerHeight = header ? header.offsetHeight : 0;
                const navHeight = nav ? nav.offsetHeight : 0;
                const totalOffset = headerHeight + navHeight;

                // Get the position of main element relative to document
                const mainRect = main.getBoundingClientRect();
                const mainTop = mainRect.top + window.pageYOffset;

                // Scroll to position that accounts for sticky header and nav
                // Add a small padding (10px) for visual spacing
                window.scrollTo({
                    top: mainTop - totalOffset - 10,
                    behavior: 'smooth'
                });
            }
        });
    });

    // Handle hash navigation on page load
    if (window.location.hash) {
        const hash = window.location.hash.substring(1);
        const tabLink = document.querySelector('[data-tab="' + hash + '"]');
        if (tabLink) {
            // Use setTimeout to ensure DOM is ready before scrolling
            setTimeout(() => {
                tabLink.click();
            }, 100);
        }
    }
}

// Setup back to top button
function setupBackToTop() {
    const backToTopBtn = document.getElementById('back-to-top');

    if (!backToTopBtn) return;

    // Show/hide button based on scroll position
    window.addEventListener('scroll', function() {
        if (window.pageYOffset > 300) {
            backToTopBtn.classList.add('visible');
        } else {
            backToTopBtn.classList.remove('visible');
        }
    });

    // Scroll to top when clicked
    backToTopBtn.addEventListener('click', function() {
        window.scrollTo({
            top: 0,
            behavior: 'smooth'
        });
    });
}

// Setup dark mode toggle (defaults to system preference)
function setupDarkMode() {
    // Check for saved theme preference, default to system preference if not set
    const savedTheme = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;

    // Only set theme if user has explicitly chosen one, otherwise use system preference
    if (savedTheme) {
        document.documentElement.setAttribute('data-theme', savedTheme);
    } else {
        // Default to system preference (don't set data-theme, let CSS media query handle it)
        document.documentElement.removeAttribute('data-theme');
    }

    // Get or find theme toggle button
    let themeToggle = document.getElementById('theme-toggle');
    if (!themeToggle) {
        return; // Button should exist in HTML
    }

    // Update button icon based on current theme
    function updateButtonIcon() {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        const isDark = currentTheme === 'dark' || (!currentTheme && prefersDark);
        const icon = themeToggle.querySelector('.theme-icon');
        if (icon) {
            icon.textContent = isDark ? '☀️' : '🌙';
        }
    }

    // Initial icon update
    updateButtonIcon();

    // Toggle theme on click
    themeToggle.addEventListener('click', function() {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        let newTheme;

        if (currentTheme === 'dark') {
            newTheme = 'light';
        } else if (currentTheme === 'light') {
            // If explicitly light, go back to system preference
            newTheme = null;
            document.documentElement.removeAttribute('data-theme');
        } else {
            // Currently using system preference, toggle to opposite
            newTheme = prefersDark ? 'light' : 'dark';
        }

        if (newTheme) {
            document.documentElement.setAttribute('data-theme', newTheme);
            localStorage.setItem('theme', newTheme);
        } else {
            document.documentElement.removeAttribute('data-theme');
            localStorage.removeItem('theme');
        }

        updateButtonIcon();
    });

    // Listen for system theme changes (only if no explicit preference)
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function(e) {
        if (!localStorage.getItem('theme')) {
            // No explicit preference, update icon to reflect system change
            updateButtonIcon();
        }
    });
}

// Fetch data when page loads
document.addEventListener('DOMContentLoaded', function() {
    setupDarkMode();
    fetchData();
    setupSearch();
    setupTabs();
    setupBackToTop();
});
