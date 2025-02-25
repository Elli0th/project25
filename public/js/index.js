// Update days in month based on selected year and month
function updateDays() {
    const yearSelect = document.getElementById('year');
    const monthSelect = document.getElementById('month');
    const daySelect = document.getElementById('day');
    
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

// Add event listeners when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    const yearSelect = document.getElementById('year');
    const monthSelect = document.getElementById('month');
    
    if (yearSelect && monthSelect) {
        yearSelect.addEventListener('change', updateDays);
        monthSelect.addEventListener('change', updateDays);
        // Initialize days on page load
        updateDays();
    }
});