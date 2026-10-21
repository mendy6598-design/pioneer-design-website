/* ------------------------------------------------------------------
   The Pioneer Design — local build interactions
   1. Responsive navigation overlay
   2. Image lightbox (mirrors the WordPress lightbox experience)
------------------------------------------------------------------ */
(function () {
    'use strict';

    /* ----------------------------------------------------------------
       1. Navigation overlay
    ---------------------------------------------------------------- */
    var nav = document.querySelector('.wp-block-navigation');
    if (nav) {
        var openBtn = nav.querySelector('.wp-block-navigation__responsive-container-open');
        var closeBtn = nav.querySelector('.wp-block-navigation__responsive-container-close');
        var panel = nav.querySelector('.wp-block-navigation__responsive-container');

        var setMenu = function (open) {
            if (!panel) return;
            panel.classList.toggle('is-menu-open', open);
            panel.classList.toggle('has-modal-open', open);
            document.body.classList.toggle('pd-menu-open', open);
            if (openBtn) openBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
            if (open && closeBtn) {
                window.setTimeout(function () { closeBtn.focus(); }, 30);
            }
            if (!open && openBtn) openBtn.focus();
        };

        if (openBtn) {
            openBtn.addEventListener('click', function (event) {
                event.preventDefault();
                setMenu(true);
            });
        }

        if (closeBtn) {
            closeBtn.addEventListener('click', function (event) {
                event.preventDefault();
                setMenu(false);
            });
        }

        if (panel) {
            panel.addEventListener('click', function (event) {
                if (event.target.closest('a')) setMenu(false);
            });
        }

        document.addEventListener('keydown', function (event) {
            if (event.key === 'Escape' && panel && panel.classList.contains('is-menu-open')) {
                setMenu(false);
            }
        });
    }

    /* ----------------------------------------------------------------
       2. Lightbox trigger positioning
       WordPress anchors each expand button to the image box inside its
       figure, which matters for images narrower or shorter than the
       figure (the default CSS assumes the image fills it).
    ---------------------------------------------------------------- */
    var positionLightboxTriggers = function () {
        var figures = document.querySelectorAll('.wp-lightbox-container');
        for (var i = 0; i < figures.length; i++) {
            var figure = figures[i];
            var img = figure.querySelector('img');
            var btn = figure.querySelector('.lightbox-trigger');
            if (!img || !btn || !img.complete || !img.naturalWidth) continue;
            var fr = figure.getBoundingClientRect();
            var ir = img.getBoundingClientRect();
            btn.style.right = Math.round(fr.right - ir.right + 16) + 'px';
            btn.style.top = (btn.hasAttribute('data-fixed-top') ? parseInt(btn.getAttribute('data-fixed-top'), 10) : Math.round(ir.top - fr.top + 16)) + 'px';
        }
    };

    window.addEventListener('load', positionLightboxTriggers);
    window.addEventListener('resize', positionLightboxTriggers);
    var lightboxImages = document.querySelectorAll('.wp-lightbox-container img');
    for (var li = 0; li < lightboxImages.length; li++) {
        lightboxImages[li].addEventListener('load', positionLightboxTriggers);
    }

    /* ----------------------------------------------------------------
       3. Lightbox
    ---------------------------------------------------------------- */
    var overlay = document.createElement('div');
    overlay.className = 'pd-lightbox';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Image viewer');
    overlay.innerHTML =
        '<button class="pd-lightbox__close" type="button" aria-label="Close image viewer">' +
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
        '<path fill="currentColor" d="m13.06 12 6.47-6.47-1.06-1.06L12 10.94 5.53 4.47 4.47 5.53 10.94 12l-6.47 6.47 1.06 1.06L12 13.06l6.47 6.47 1.06-1.06L13.06 12Z"/>' +
        '</svg></button>' +
        '<img alt="" />';
    document.body.appendChild(overlay);

    var overlayImg = overlay.querySelector('img');
    var lastFocused = null;

    var openLightbox = function (src, alt) {
        if (!src) return;
        lastFocused = document.activeElement;
        overlayImg.src = src;
        overlayImg.alt = alt || '';
        overlay.classList.add('is-open');
        document.documentElement.classList.add('pd-lb-open');
        document.body.classList.add('pd-lb-open');
        var close = overlay.querySelector('.pd-lightbox__close');
        if (close) close.focus();
    };

    var closeLightbox = function () {
        overlay.classList.remove('is-open');
        document.documentElement.classList.remove('pd-lb-open');
        document.body.classList.remove('pd-lb-open');
        window.setTimeout(function () {
            if (!overlay.classList.contains('is-open')) overlayImg.removeAttribute('src');
        }, 200);
        if (lastFocused && lastFocused.focus) lastFocused.focus();
    };

    document.addEventListener('click', function (event) {
        var trigger = event.target.closest('.wp-lightbox-container img, .wp-lightbox-container .lightbox-trigger, .pd-gallery-item img');
        if (trigger) {
            var figure = trigger.closest('.wp-lightbox-container, .pd-gallery-item');
            var img = figure ? figure.querySelector('img') : null;
            if (img) {
                event.preventDefault();
                openLightbox(img.currentSrc || img.src, img.alt);
            }
            return;
        }

        if (event.target === overlay || event.target.closest('.pd-lightbox__close')) {
            event.preventDefault();
            closeLightbox();
        }
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && overlay.classList.contains('is-open')) {
            closeLightbox();
        }
    });

    /* ----------------------------------------------------------------
       4. Contact form (static demo)
       The markup ships Jetpack's success panel; without a backend we show
       it locally instead of posting and losing the visitor's message.
    ---------------------------------------------------------------- */
    var form = document.querySelector('form.contact-form');
    var success = document.querySelector('.contact-form-submission');
    if (form && success) {
        var showSuccess = function () {
            form.style.display = 'none';
            success.style.display = 'block';
            success.focus();
            success.scrollIntoView({ block: 'center', behavior: 'smooth' });
        };
        var showForm = function () {
            success.style.display = 'none';
            form.style.display = '';
            form.reset();
            var firstField = form.querySelector('input[type="text"], input[type="email"]');
            if (firstField) firstField.focus();
        };

        form.addEventListener('submit', function (event) {
            event.preventDefault();
            if (form.checkValidity && !form.checkValidity()) {
                form.reportValidity();
                return;
            }
            showSuccess();
        });

        var back = success.querySelector('.go-back-message a');
        if (back) {
            back.addEventListener('click', function (event) {
                event.preventDefault();
                showForm();
            });
        }
    }
})();
