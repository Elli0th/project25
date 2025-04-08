/**
 * JavaScript functionality for the Budget App
 * 
 * Functions:
 * - Calendar date handling (updateDays)
 * - Password visualization toggle (togglePassword)
 * - Password strength checking (checkPasswordStrength)
 * - Password matching validation (checkPasswordsMatch)
 * - Form validation (setupFormValidation)
 * - CSRF token handling (setupCsrfProtection)
 */


// Update days in month based on selected year and month
function updateDays() {
    const yearSelect = document.getElementById('year');
    const monthSelect = document.getElementById('month');
    const daySelect = document.getElementById('day');
    
    if (!yearSelect || !monthSelect || !daySelect) return;
    
    const year = parseInt(yearSelect.value);
    const month = parseInt(monthSelect.value);
    
    // Get number of days in selected month (month is 1-based in form but 0-based in Date)
    const daysInMonth = new Date(year, month, 0).getDate();
    
    // Save currently selected day
    const currentDay = parseInt(daySelect.value);
    
    // Clear existing options
    daySelect.innerHTML = '';
    
    // Add new options
    for (let i = 1; i <= daysInMonth; i++) {
        const option = document.createElement('option');
        option.value = i;
        option.textContent = i;
        daySelect.appendChild(option);
    }
    
    // Try to restore previous selection if valid, otherwise select last day
    if (currentDay && currentDay <= daysInMonth) {
        daySelect.value = currentDay;
    } else {
        daySelect.value = daysInMonth;
    }
}

// Enhanced security for cookies
function setupCsrfProtection() {
    // Add CSRF token to all forms
    document.querySelectorAll('form').forEach(form => {
        // Skip forms that already have the token
        if (!form.querySelector('input[name="_csrf"]')) {
            const csrfToken = document.cookie
                .split('; ')
                .find(row => row.startsWith('csrf_token='))
                ?.split('=')[1];
                
            if (csrfToken) {
                const input = document.createElement('input');
                input.type = 'hidden';
                input.name = '_csrf';
                input.value = csrfToken;
                form.appendChild(input);
            }
        }
    });
}

// Password related functions
function togglePassword(id) {
    const input = document.getElementById(id);
    if (!input) return;
    
    const button = input.nextElementSibling;
    if (input.type === 'password') {
        input.type = 'text';
        button.innerHTML = '👁️';
    } else {
        input.type = 'password';
        button.innerHTML = '👁️‍🗨️';
    }
}

function checkPasswordStrength(password) {
    const strengthBar = document.querySelector('.strength-bar');
    const strengthText = document.querySelector('.strength-text');
    
    if (!strengthBar || !strengthText) return;
    
    let strength = 0;
    
    // Length check
    if (password.length >= 8) strength += 1;
    
    // Check if password contains both uppercase and lowercase letters
    if (/[a-z]/.test(password) && /[A-Z]/.test(password)) strength += 1;
    
    // Check if password contains numbers
    if (/\d/.test(password)) strength += 1;
    
    // Check if password contains special characters
    if (/[^a-zA-Z0-9]/.test(password)) strength += 1;
    
    // Remove previous classes
    strengthBar.classList.remove('weak', 'medium', 'strong');
    
    if (password.length === 0) {
        strengthText.textContent = 'Lösenordsstyrka';
        return;
    }
    
    if (strength < 2) {
        strengthBar.classList.add('weak');
        strengthText.textContent = 'Svagt';
    } else if (strength < 4) {
        strengthBar.classList.add('medium');
        strengthText.textContent = 'Medium';
    } else {
        strengthBar.classList.add('strong');
        strengthText.textContent = 'Starkt';
    }
}

function checkPasswordsMatch() {
    const password = document.getElementById('password');
    const confirm = document.getElementById('confirm_password');
    const matchIcon = document.querySelector('.passwords-match-icon');
    
    if (!password || !confirm || !matchIcon) return;
    
    // If confirmation field is empty
    if (confirm.value.length === 0) {
        matchIcon.classList.remove('match', 'mismatch');
        return;
    }
    
    if (password.value === confirm.value) {
        matchIcon.classList.add('match');
        matchIcon.classList.remove('mismatch');
    } else {
        matchIcon.classList.add('mismatch');
        matchIcon.classList.remove('match');
    }
}

// Popup functionality (maintained for backward compatibility)
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

// Setup all event listeners
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
    
    // Setup password toggle buttons
    const toggleButtons = document.querySelectorAll('.password-toggle');
    toggleButtons.forEach(button => {
        if (!button.getAttribute('onclick')) {  // Only add listener if not using inline onclick
            button.addEventListener('click', function() {
                const input = this.previousElementSibling;
                togglePassword(input.id);
            });
        }
        // Set initial icon
        button.innerHTML = '👁️‍🗨️';
    });
    
    // Setup password strength meter
    const passwordInput = document.getElementById('password');
    if (passwordInput && !passwordInput.getAttribute('oninput')) { // Only add if not using inline
        passwordInput.addEventListener('input', function() {
            checkPasswordStrength(this.value);
            checkPasswordsMatch();
        });
    }
    
    // Setup password confirmation check
    const confirmInput = document.getElementById('confirm_password');
    if (confirmInput && !confirmInput.getAttribute('oninput')) { // Only add if not using inline
        confirmInput.addEventListener('input', checkPasswordsMatch);
    }
    
    // Form validation for signup
    const signupForm = document.getElementById('signup-form');
    if (signupForm) {
        signupForm.addEventListener('submit', function(event) {
            const password = document.getElementById('password');
            const confirm = document.getElementById('confirm_password');
            
            if (password && confirm && password.value !== confirm.value) {
                event.preventDefault();
                alert('Lösenorden matchar inte!');
                return false;
            }
        });
    }
    
    // Legacy popup functionality (for backward compatibility)
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
    
    // Add CSRF protection to forms
    setupCsrfProtection();
});