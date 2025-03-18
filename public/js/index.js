// Update days in month based on selected year and month
function updateDays() {
    const yearSelect = document.getElementById('year');
    const monthSelect = document.getElementById('month');
    const daySelect = document.getElementById('day');
    
    if (!yearSelect || !monthSelect || !daySelect) return;
    
    const year = parseInt(yearSelect.value);
    const month = parseInt(monthSelect.value);
    
    // Get number of days in selected month
    const daysInMonth = new Date(year, month, 0).getDate();
    
    // Clear existing options
    daySelect.innerHTML = '';
    
    // Add new options
    for (let i = 1; i <= daysInMonth; i++) {
        const option = document.createElement('option');
        option.value = i;
        option.textContent = i;
        daySelect.appendChild(option);
    }
}

// Popup functionality
function showLoginPopup() {
    const overlay = document.getElementById('popup-overlay');
    if (overlay) {
        overlay.classList.add('active');
    }
}

function hideLoginPopup() {
    const overlay = document.getElementById('popup-overlay');
    if (overlay) {
        overlay.classList.remove('active');
    }
}

function setupLoginPopupListeners() {
    // Close button
    const closeBtn = document.getElementById('popup-close');
    if (closeBtn) {
        closeBtn.addEventListener('click', hideLoginPopup);
    }
    
    // Tab switching
    const tabs = document.querySelectorAll('.popup-tab');
    tabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // Remove active class from all tabs
            tabs.forEach(t => t.classList.remove('active'));
            
            // Add active class to clicked tab
            this.classList.add('active');
            
            // Hide all content
            const contents = document.querySelectorAll('.tab-content');
            contents.forEach(content => content.classList.remove('active'));
            
            // Show content for clicked tab
            const targetId = this.getAttribute('data-target');
            const targetContent = document.getElementById(targetId);
            if (targetContent) {
                targetContent.classList.add('active');
            }
        });
    });
    
    // Click outside to close
    const overlay = document.getElementById('popup-overlay');
    if (overlay) {
        overlay.addEventListener('click', function(e) {
            if (e.target === overlay) {
                hideLoginPopup();
            }
        });
    }
}

// Add event listeners when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    // Calendar functionality
    const yearSelect = document.getElementById('year');
    const monthSelect = document.getElementById('month');
    
    if (yearSelect && monthSelect) {
        yearSelect.addEventListener('change', updateDays);
        monthSelect.addEventListener('change', updateDays);
        // Initialize days on page load
        updateDays();
    }
    
    // Setup popup listeners
    setupLoginPopupListeners();
    
    // Check if user is already logged in
    if (!document.cookie.includes('user_logged_in=true')) {
        // Show popup on home page only
        if (window.location.pathname === '/' || window.location.pathname === '') {
            showLoginPopup();
        }
    }
});