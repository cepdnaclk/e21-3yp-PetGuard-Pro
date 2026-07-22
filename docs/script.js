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
    
    // Bottom Navigation Bar Items
    const navHome = document.getElementById('btn-tab-home');
    const navMap = document.getElementById('btn-tab-map');
    const navSupport = document.getElementById('btn-tab-support');

    // Simulator Tab Panels
    const tabHome = document.getElementById('phone-tab-home');
    const tabMap = document.getElementById('phone-tab-map');
    const tabSupport = document.getElementById('phone-tab-support');

    let stepCounter = 2450;
    let stepInterval = null;

    function switchSimTab(tabId) {
        // Reset navigation links
        [navHome, navMap, navSupport].forEach(btn => btn.classList.remove('active'));
        [tabHome, tabMap, tabSupport].forEach(panel => panel.classList.remove('active'));

        if (tabId === 'home') {
            navHome.classList.add('active');
            tabHome.classList.add('active');
        } else if (tabId === 'map') {
            navMap.classList.add('active');
            tabMap.classList.add('active');
        } else if (tabId === 'support') {
            navSupport.classList.add('active');
            tabSupport.classList.add('active');
        }
    }

    navHome.addEventListener('click', () => switchSimTab('home'));
    navMap.addEventListener('click', () => switchSimTab('map'));
    navSupport.addEventListener('click', () => switchSimTab('support'));

    function updatePhoneDashboard(featureId) {
        // Clear active intervals
        if (stepInterval) {
            clearInterval(stepInterval);
            stepInterval = null;
        }

        // Reset status banner widgets
        const statusBanner = document.getElementById('sim-status-banner');
        const statusIcon = document.getElementById('sim-status-icon');
        const statusTitle = document.getElementById('sim-status-title');
        const statusSub = document.getElementById('sim-status-sub');

        statusBanner.className = 'phone-status-banner';
        statusIcon.textContent = '✓';
        statusTitle.textContent = 'Collar Status: Online';
        statusSub.textContent = 'Collar is online and transmitting data.';

        // Map widgets
        const mapMarker = document.getElementById('sim-map-marker');
        const mapBg = document.getElementById('sim-map-bg');
        const alertBadge = document.getElementById('sim-fence-alert');

        mapMarker.className = 'phone-map-marker';
        alertBadge.className = 'phone-fence-alert';

        // Metric card values
        const hrVal = document.getElementById('sim-hr-val');
        const hrSub = document.getElementById('sim-hr-sub');
        const tempVal = document.getElementById('sim-temp-val');
        const tempSub = document.getElementById('sim-temp-sub');
        const stepsVal = document.getElementById('sim-steps-val');
        const stepsSub = document.getElementById('sim-steps-sub');
        const actVal = document.getElementById('sim-act-val');
        const actSub = document.getElementById('sim-act-sub');

        // Today activity values
        const todayDist = document.getElementById('sim-today-dist');
        const todayTime = document.getElementById('sim-today-time');
        const todayActive = document.getElementById('sim-today-active');

        // Reset opacity of metric cards
        document.querySelectorAll('.phone-metric-card').forEach(card => card.style.opacity = '1');

        switch(featureId) {
            case 'feat-connection':
                switchSimTab('home');
                hrVal.textContent = '72 BPM';
                hrSub.textContent = 'Normal vital bounds';
                tempVal.textContent = '38.2 °C';
                tempSub.textContent = 'Normal range';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = '49% of daily goal';
                actVal.textContent = 'RESTING';
                actSub.textContent = 'Sleeping / Inactive';
                break;

            case 'feat-vitals':
                switchSimTab('home');
                hrVal.textContent = '78 BPM';
                hrSub.textContent = 'Normal vital bounds';
                tempVal.textContent = '38.3 °C';
                tempSub.textContent = 'Normal range';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = 'Telemetry sync active';
                actVal.textContent = 'WALKING';
                actSub.textContent = 'Normal mobility logged';
                break;

            case 'feat-steps':
                switchSimTab('home');
                hrVal.textContent = '122 BPM';
                hrSub.textContent = 'Elevated pulse (Active)';
                tempVal.textContent = '38.8 °C';
                tempSub.textContent = 'Normal range';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = 'Walking actively';
                actVal.textContent = 'RUNNING';
                actSub.textContent = 'Active play state';

                stepInterval = setInterval(() => {
                    stepCounter += Math.floor(Math.random() * 2) + 1;
                    stepsVal.textContent = stepCounter + ' steps';
                    const activeHr = 120 + Math.floor(Math.random() * 6);
                    hrVal.textContent = activeHr + ' BPM';
                }, 1000);
                break;

            case 'feat-fence':
                switchSimTab('map');
                mapMarker.classList.add('out-of-bounds');
                mapMarker.style.top = '15%';
                mapMarker.style.left = '80%';
                mapBg.style.backgroundPosition = '-80px -60px';
                alertBadge.classList.add('active');

                // Update home state in background
                hrVal.textContent = '138 BPM';
                hrSub.textContent = 'Elevated pulse (Running)';
                tempVal.textContent = '39.0 °C';
                tempSub.textContent = 'Fever warning threshold';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = '49% of daily goal';
                actVal.textContent = 'RUNNING';
                actSub.textContent = 'Active play state';

                todayDist.textContent = '1.4 km';
                todayTime.textContent = 'Just now';
                todayActive.textContent = '55 min';
                break;

            case 'feat-reports':
                switchSimTab('home');
                hrVal.textContent = '74 BPM';
                hrSub.textContent = 'Normal vital bounds';
                tempVal.textContent = '38.2 °C';
                tempSub.textContent = 'Normal range';
                stepsVal.textContent = stepCounter + ' steps';
                stepsSub.textContent = 'Compiling behavior report';
                actVal.textContent = 'RESTING';
                actSub.textContent = 'Sleeping / Inactive';
                break;

            case 'feat-tickets':
                switchSimTab('support');
                statusBanner.classList.add('offline');
                statusIcon.textContent = '⚠️';
                statusTitle.textContent = 'Collar Status: Offline';
                statusSub.textContent = 'Collar is currently disconnected or offline.';

                document.querySelectorAll('.phone-metric-card').forEach(card => card.style.opacity = '0.35');

                hrVal.textContent = '-- BPM';
                hrSub.textContent = 'System Offline';
                tempVal.textContent = '-- °C';
                tempSub.textContent = 'System Offline';
                stepsVal.textContent = 'Offline';
                stepsSub.textContent = 'Last synced: 1m ago';
                actVal.textContent = 'OFFLINE';
                actSub.textContent = 'Collar turned off';
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

    // Support ticket action
    const ticketBtn = document.getElementById('sim-ticket-btn');
    const ticketStatus = document.getElementById('sim-ticket-status');
    if (ticketBtn && ticketStatus) {
        ticketBtn.addEventListener('click', () => {
            ticketStatus.textContent = 'Ticket #PG-8041 Opened in Firestore';
            ticketStatus.style.color = '#10b981';
        });
    }

    // Default selection on page start
    updatePhoneDashboard('feat-connection');
})();

// Image Lightbox Interactivity
(function() {
    const probeImg = document.querySelector('.probe-img');
    const lightbox = document.createElement('div');
    lightbox.id = 'image-lightbox';
    lightbox.className = 'lightbox';
    lightbox.innerHTML = `
        <span class="lightbox-close">&times;</span>
        <img class="lightbox-content" id="lightbox-img" alt="Enlarged View">
    `;
    document.body.appendChild(lightbox);

    const lightboxImg = lightbox.querySelector('#lightbox-img');
    const closeBtn = lightbox.querySelector('.lightbox-close');

    if (probeImg) {
        probeImg.style.cursor = 'zoom-in';
        probeImg.addEventListener('click', () => {
            lightboxImg.src = probeImg.src;
            lightbox.classList.add('active');
            document.body.style.overflow = 'hidden'; // Disable page scrolling
        });
    }

    const closeLightbox = () => {
        lightbox.classList.remove('active');
        document.body.style.overflow = 'auto'; // Re-enable page scrolling
    };

    closeBtn.addEventListener('click', closeLightbox);
    lightbox.addEventListener('click', (e) => {
        if (e.target === lightbox) {
            closeLightbox();
        }
    });
})();
