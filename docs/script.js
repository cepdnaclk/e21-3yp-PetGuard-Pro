// Intersection Observer for scroll animations
const observer = new IntersectionObserver(
    (entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                entry.target.classList.add('vis');
            }
        });
    },
    { threshold: 0.05 }
);

document.querySelectorAll('.rev').forEach((el) => observer.observe(el));

// Interactive Architecture Tabs Switcher
function arcSwitchTab(tabIndex) {
    const tabs = document.querySelectorAll('.arc-tab');
    const panels = document.querySelectorAll('.arc-panels .arc-panel');

    tabs.forEach((tab, index) => {
        if (index === tabIndex) {
            tab.classList.add('active');
        } else {
            tab.classList.remove('active');
        }
    });

    panels.forEach((panel, index) => {
        if (index === tabIndex) {
            panel.classList.add('active');
        } else {
            panel.classList.remove('active');
        }
    });
}

// Dark / Light mode handler
(function () {
    const toggle = document.getElementById('theme-toggle');
    const root = document.documentElement;

    const savedTheme = localStorage.getItem('petguard-theme') || 'dark';
    if (savedTheme === 'light') {
        root.setAttribute('data-theme', 'light');
    }

    toggle.addEventListener('click', () => {
        const currentTheme = root.getAttribute('data-theme');
        if (currentTheme === 'light') {
            root.removeAttribute('data-theme');
            localStorage.setItem('petguard-theme', 'dark');
        } else {
            root.setAttribute('data-theme', 'light');
            localStorage.setItem('petguard-theme', 'light');
        }
    });
})();

// Mobile responsive menu toggle
(function () {
    const hamburger = document.getElementById('nav-hamburger');
    const nav = document.querySelector('nav');

    hamburger.addEventListener('click', () => {
        nav.classList.toggle('mobile-open');
    });

    document.querySelectorAll('.nls a').forEach((link) => {
        link.addEventListener('click', () => {
            nav.classList.remove('mobile-open');
        });
    });
})();

// Typewriter subtitle animation
class TypewriterEffect {
    constructor(element, texts, speed = 80, delay = 2000) {
        this.element = element;
        this.texts = texts;
        this.speed = speed;
        this.delay = delay;
        this.listIndex = 0;
        this.charIndex = 0;
        this.isDeleting = false;
    }

    start() {
        this.type();
    }

    type() {
        const fullText = this.texts[this.listIndex];
        if (this.isDeleting) {
            this.element.textContent = fullText.substring(0, this.charIndex - 1);
            this.charIndex--;
        } else {
            this.element.textContent = fullText.substring(0, this.charIndex + 1);
            this.charIndex++;
        }

        let speed = this.speed;
        if (this.isDeleting) speed /= 1.5;

        if (!this.isDeleting && this.charIndex === fullText.length) {
            this.isDeleting = true;
            speed = this.delay;
        } else if (this.isDeleting && this.charIndex === 0) {
            this.isDeleting = false;
            this.listIndex = (this.listIndex + 1) % this.texts.length;
            speed = 500;
        }

        setTimeout(() => this.type(), speed);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const typewriter = document.querySelector('.typewriter-text');
    if (typewriter) {
        const options = [
            "Real-Time Telemetry Streaming & Safe Zones",
            "Continuous Heart Rate & Temperature Monitoring",
            "Accelerometer-Based Step Tracking Progress",
            "Daily Behavior Reports Compiled to PDF"
        ];
        new TypewriterEffect(typewriter, options).start();
    }
});

// Interactive Feature List side-by-side with Phone Mockup Simulator
(function () {
    const featureItems = document.querySelectorAll('.fi');
    
    // Smartphone mockup displays
    const statusText = document.getElementById('sim-status-txt');
    const statusIndicator = document.getElementById('sim-status-ind');
    const mapMarker = document.getElementById('sim-map-marker');
    const mapBg = document.getElementById('sim-map-bg');
    const alertBadge = document.getElementById('sim-fence-alert');
    
    const hrVal = document.getElementById('sim-hr-val');
    const tempVal = document.getElementById('sim-temp-val');
    const stepsVal = document.getElementById('sim-steps-val');
    const stepsSub = document.getElementById('sim-steps-sub');
    const activityIcon = document.getElementById('sim-act-icon');
    const activityName = document.getElementById('sim-act-name');
    const activityDesc = document.getElementById('sim-act-desc');

    let stepCounter = 2450;
    let stepInterval = null;

    function updatePhoneDashboard(featureId) {
        // Clear steps increment loops
        if (stepInterval) {
            clearInterval(stepInterval);
            stepInterval = null;
        }

        // Reset default styling classes
        statusIndicator.className = 'phone-header-status';
        mapMarker.className = 'phone-map-marker';
        alertBadge.className = 'phone-fence-alert';
        
        document.getElementById('sim-vitals-row').style.opacity = '1';
        document.getElementById('sim-activity-card').style.opacity = '1';

        switch(featureId) {
            case 'feat-connection':
                statusText.textContent = 'Collar Status: Online';
                mapMarker.style.top = '50%';
                mapMarker.style.left = '50%';
                mapBg.style.backgroundPosition = '0px 0px';
                
                hrVal.textContent = '72 BPM';
                tempVal.textContent = '38.2 °C';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = 'Daily goal: 5,000 steps';
                
                activityIcon.textContent = '💤';
                activityName.textContent = 'Resting';
                activityDesc.textContent = 'Pet behavior classified as resting/sleeping';
                break;
                
            case 'feat-vitals':
                statusText.textContent = 'Collar Status: Online';
                mapMarker.style.top = '48%';
                mapMarker.style.left = '48%';
                mapBg.style.backgroundPosition = '-5px -5px';
                
                hrVal.textContent = '78 BPM';
                tempVal.textContent = '38.3 °C';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = 'Telemetry sync active';
                
                activityIcon.textContent = '🐕';
                activityName.textContent = 'Walking';
                activityDesc.textContent = 'Normal vitals parameters logged';
                break;
                
            case 'feat-steps':
                statusText.textContent = 'Collar Status: Online';
                mapMarker.style.top = '42%';
                mapMarker.style.left = '56%';
                mapBg.style.backgroundPosition = '-20px -10px';
                
                hrVal.textContent = '122 BPM';
                tempVal.textContent = '38.8 °C';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = 'Walking actively';
                
                activityIcon.textContent = '🏃';
                activityName.textContent = 'Running';
                activityDesc.textContent = 'Accelerometer step goals sync active';

                // Increments steps live
                stepInterval = setInterval(() => {
                    stepCounter += Math.floor(Math.random() * 2) + 1;
                    stepsVal.textContent = stepCounter + ' steps';
                    
                    const activeHr = 120 + Math.floor(Math.random() * 6);
                    hrVal.textContent = activeHr + ' BPM';
                }, 1000);
                break;
                
            case 'feat-fence':
                statusText.textContent = 'Collar Status: Online';
                mapMarker.classList.add('out-of-bounds');
                mapMarker.style.top = '15%';
                mapMarker.style.left = '80%';
                mapBg.style.backgroundPosition = '-80px -60px';
                alertBadge.classList.add('active');
                
                hrVal.textContent = '138 BPM';
                tempVal.textContent = '39.0 °C';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = 'Outside safe boundary!';
                
                activityIcon.textContent = '⚠️';
                activityName.textContent = 'Breach Escape';
                activityDesc.textContent = 'Buzzer alarm active / owner notified';
                break;
                
            case 'feat-reports':
                statusText.textContent = 'Collar Status: Online';
                mapMarker.style.top = '50%';
                mapMarker.style.left = '50%';
                mapBg.style.backgroundPosition = '0px 0px';
                
                hrVal.textContent = '74 BPM';
                tempVal.textContent = '38.2 °C';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = 'Compiling behavior charts';
                
                activityIcon.textContent = '📊';
                activityName.textContent = 'PDF Logs';
                activityDesc.textContent = 'Exportable metrics summary compiled';
                break;
                
            case 'feat-tickets':
                statusText.textContent = 'Collar Status: Offline';
                statusIndicator.classList.add('offline');
                mapMarker.style.top = '50%';
                mapMarker.style.left = '50%';
                mapBg.style.backgroundPosition = '0px 0px';
                
                document.getElementById('sim-vitals-row').style.opacity = '0.35';
                document.getElementById('sim-activity-card').style.opacity = '0.35';
                
                hrVal.textContent = '-- BPM';
                tempVal.textContent = '-- °C';
                stepsVal.textContent = 'Offline';
                stepsSub.textContent = 'Last synced: 1 minute ago';
                
                activityIcon.textContent = '🔌';
                activityName.textContent = 'Disconnected';
                activityDesc.textContent = 'Collar turned off / system offline';
                break;
        }
    }

    featureItems.forEach((item) => {
        item.addEventListener('click', () => {
            featureItems.forEach((i) => i.classList.remove('act'));
            item.classList.add('act');
            const id = item.getAttribute('id');
            updatePhoneDashboard(id);
        });
    });

    // Default selection on page start
    updatePhoneDashboard('feat-connection');
})();
