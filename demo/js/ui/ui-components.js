/**
 * THE FADING RAVEN - UI Components System
 * 공통 UI 컴포넌트: 툴팁, 토스트, 모달, 진행바
 */

// ============================================
// TOOLTIP SYSTEM
// ============================================
const Tooltip = {
    element: null,
    hideTimeout: null,

    init() {
        // 툴팁 컨테이너 생성
        this.element = document.createElement('div');
        this.element.className = 'ui-tooltip';
        this.element.id = 'ui-tooltip-container';
        // 접근성: tooltip role
        this.element.setAttribute('role', 'tooltip');
        this.element.setAttribute('aria-hidden', 'true');
        this.element.innerHTML = `
            <div class="tooltip-title"></div>
            <div class="tooltip-content"></div>
        `;
        document.body.appendChild(this.element);

        // 전역 이벤트 바인딩
        document.addEventListener('mouseover', (e) => this.handleMouseOver(e));
        document.addEventListener('mouseout', (e) => this.handleMouseOut(e));
        document.addEventListener('mousemove', (e) => this.handleMouseMove(e));

        console.log('Tooltip system initialized');
    },

    handleMouseOver(e) {
        const target = e.target.closest('[data-tooltip]');
        if (!target) return;

        clearTimeout(this.hideTimeout);

        const title = target.dataset.tooltipTitle || '';
        const content = target.dataset.tooltip;

        this.show(title, content, e);
    },

    handleMouseOut(e) {
        const target = e.target.closest('[data-tooltip]');
        if (!target) return;

        this.hideTimeout = setTimeout(() => this.hide(), 100);
    },

    handleMouseMove(e) {
        if (!this.element.classList.contains('visible')) return;
        this.updatePosition(e.clientX, e.clientY);
    },

    show(title, content, e) {
        const titleEl = this.element.querySelector('.tooltip-title');
        const contentEl = this.element.querySelector('.tooltip-content');

        titleEl.textContent = title;
        titleEl.style.display = title ? 'block' : 'none';
        contentEl.innerHTML = content;

        this.element.classList.add('visible');
        this.element.setAttribute('aria-hidden', 'false');
        this.updatePosition(e.clientX, e.clientY);
    },

    hide() {
        this.element.classList.remove('visible');
        this.element.setAttribute('aria-hidden', 'true');
    },

    updatePosition(x, y) {
        const rect = this.element.getBoundingClientRect();
        const padding = 12;

        // 화면 경계 체크
        let left = x + padding;
        let top = y + padding;

        if (left + rect.width > window.innerWidth) {
            left = x - rect.width - padding;
        }
        if (top + rect.height > window.innerHeight) {
            top = y - rect.height - padding;
        }

        this.element.style.left = `${left}px`;
        this.element.style.top = `${top}px`;
    },

    // 프로그래매틱 사용
    showAt(x, y, title, content) {
        const titleEl = this.element.querySelector('.tooltip-title');
        const contentEl = this.element.querySelector('.tooltip-content');

        titleEl.textContent = title;
        titleEl.style.display = title ? 'block' : 'none';
        contentEl.innerHTML = content;

        this.element.classList.add('visible');
        this.element.setAttribute('aria-hidden', 'false');
        this.updatePosition(x, y);
    }
};

// ============================================
// TOAST NOTIFICATION SYSTEM
// ============================================
const Toast = {
    container: null,
    queue: [],
    maxVisible: 3,

    init() {
        this.container = document.createElement('div');
        this.container.className = 'ui-toast-container';
        // 접근성: 스크린 리더용 live region
        this.container.setAttribute('role', 'region');
        this.container.setAttribute('aria-live', 'polite');
        this.container.setAttribute('aria-label', '알림 메시지');
        document.body.appendChild(this.container);

        console.log('Toast system initialized');
    },

    /**
     * 토스트 메시지 표시
     * @param {string} message - 메시지 내용
     * @param {string} type - 'info' | 'success' | 'warning' | 'error'
     * @param {number} duration - 표시 시간 (ms), 기본 3000
     */
    show(message, type = 'info', duration = 3000) {
        const toast = document.createElement('div');
        toast.className = `ui-toast ui-toast-${type}`;
        // 접근성: role과 aria-label
        toast.setAttribute('role', type === 'error' ? 'alert' : 'status');
        toast.innerHTML = `
            <span class="toast-icon" aria-hidden="true">${this.getIcon(type)}</span>
            <span class="toast-message">${message}</span>
            <button class="toast-close" aria-label="알림 닫기">&times;</button>
        `;

        // 닫기 버튼 이벤트
        toast.querySelector('.toast-close').addEventListener('click', () => {
            this.dismiss(toast);
        });

        // 컨테이너에 추가
        this.container.appendChild(toast);

        // 애니메이션 트리거
        requestAnimationFrame(() => {
            toast.classList.add('visible');
        });

        // 자동 제거
        if (duration > 0) {
            setTimeout(() => this.dismiss(toast), duration);
        }

        // 최대 개수 제한
        this.enforceLimit();

        return toast;
    },

    dismiss(toast) {
        if (!toast || !toast.parentNode) return;

        toast.classList.remove('visible');
        toast.classList.add('hiding');

        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 300);
    },

    enforceLimit() {
        const toasts = this.container.querySelectorAll('.ui-toast:not(.hiding)');
        if (toasts.length > this.maxVisible) {
            for (let i = 0; i < toasts.length - this.maxVisible; i++) {
                this.dismiss(toasts[i]);
            }
        }
    },

    getIcon(type) {
        const icons = {
            info: 'i',
            success: '✓',
            warning: '!',
            error: '✕'
        };
        return icons[type] || icons.info;
    },

    // 편의 메서드
    info(message, duration) { return this.show(message, 'info', duration); },
    success(message, duration) { return this.show(message, 'success', duration); },
    warning(message, duration) { return this.show(message, 'warning', duration); },
    error(message, duration) { return this.show(message, 'error', duration); }
};

// ============================================
// MODAL MANAGER
// ============================================
const ModalManager = {
    stack: [],
    overlay: null,

    init() {
        // 오버레이 생성
        this.overlay = document.createElement('div');
        this.overlay.className = 'ui-modal-overlay';
        this.overlay.addEventListener('click', (e) => {
            if (e.target === this.overlay) {
                this.closeTop();
            }
        });
        document.body.appendChild(this.overlay);

        // ESC 키 처리
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.stack.length > 0) {
                const topModal = this.stack[this.stack.length - 1];
                if (topModal.closeOnEsc !== false) {
                    this.close(topModal.id);
                }
            }
        });

        console.log('ModalManager initialized');
    },

    /**
     * 모달 열기
     * @param {Object} options
     * @param {string} options.id - 모달 ID
     * @param {string} options.title - 제목
     * @param {string} options.content - HTML 내용
     * @param {Array} options.buttons - 버튼 배열 [{label, class, onClick}]
     * @param {boolean} options.closeOnEsc - ESC로 닫기 허용
     * @param {boolean} options.closeOnOverlay - 오버레이 클릭으로 닫기 허용
     * @param {string} options.size - 'small' | 'medium' | 'large'
     */
    open(options) {
        const {
            id = `modal-${Date.now()}`,
            title = '',
            content = '',
            buttons = [],
            closeOnEsc = true,
            closeOnOverlay = true,
            size = 'medium',
            onClose = null
        } = options;

        // 이미 열린 모달인지 체크
        if (this.stack.find(m => m.id === id)) {
            console.warn(`Modal ${id} is already open`);
            return;
        }

        // 모달 요소 생성
        const modal = document.createElement('div');
        modal.className = `ui-modal ui-modal-${size}`;
        modal.id = id;
        // 접근성: dialog role과 aria 속성
        modal.setAttribute('role', 'dialog');
        modal.setAttribute('aria-modal', 'true');
        modal.setAttribute('aria-labelledby', `${id}-title`);
        modal.setAttribute('tabindex', '-1');
        modal.innerHTML = `
            <div class="modal-header">
                <h3 class="modal-title" id="${id}-title">${title}</h3>
                <button class="modal-close" aria-label="닫기">&times;</button>
            </div>
            <div class="modal-body">${content}</div>
            ${buttons.length > 0 ? `
                <div class="modal-footer">
                    ${buttons.map((btn, i) => `
                        <button class="modal-btn ${btn.class || ''}" data-btn-index="${i}">
                            ${btn.label}
                        </button>
                    `).join('')}
                </div>
            ` : ''}
        `;

        // 닫기 버튼 이벤트
        modal.querySelector('.modal-close').addEventListener('click', () => {
            this.close(id);
        });

        // 버튼 이벤트
        buttons.forEach((btn, i) => {
            const btnEl = modal.querySelector(`[data-btn-index="${i}"]`);
            if (btnEl && btn.onClick) {
                btnEl.addEventListener('click', () => btn.onClick(this, id));
            }
        });

        // 포커스 트랩 설정 (접근성)
        this.setupFocusTrap(modal);

        // 이전 포커스 요소 저장
        const previouslyFocused = document.activeElement;

        // 스택에 추가
        this.stack.push({ id, element: modal, closeOnEsc, closeOnOverlay, onClose, previouslyFocused });

        // DOM에 추가
        this.overlay.appendChild(modal);
        this.overlay.classList.add('visible');

        // 애니메이션 및 포커스 이동
        requestAnimationFrame(() => {
            modal.classList.add('visible');
            // 모달 내 첫 번째 포커스 가능 요소로 이동
            const firstFocusable = modal.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
            if (firstFocusable) {
                firstFocusable.focus();
            } else {
                modal.focus();
            }
        });

        return id;
    },

    // 포커스 트랩 설정 (모달 내에서만 Tab 이동)
    setupFocusTrap(modal) {
        modal.addEventListener('keydown', (e) => {
            if (e.key !== 'Tab') return;

            const focusableElements = modal.querySelectorAll(
                'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
            );
            const firstEl = focusableElements[0];
            const lastEl = focusableElements[focusableElements.length - 1];

            if (e.shiftKey && document.activeElement === firstEl) {
                e.preventDefault();
                lastEl.focus();
            } else if (!e.shiftKey && document.activeElement === lastEl) {
                e.preventDefault();
                firstEl.focus();
            }
        });
    },

    close(id) {
        const index = this.stack.findIndex(m => m.id === id);
        if (index === -1) return;

        const modalData = this.stack[index];
        const modal = modalData.element;

        // 콜백 실행
        if (modalData.onClose) {
            modalData.onClose();
        }

        // 애니메이션 후 제거
        modal.classList.remove('visible');
        setTimeout(() => {
            if (modal.parentNode) {
                modal.parentNode.removeChild(modal);
            }
        }, 300);

        // 스택에서 제거
        this.stack.splice(index, 1);

        // 오버레이 숨김
        if (this.stack.length === 0) {
            this.overlay.classList.remove('visible');
        }

        // 이전 포커스 복원 (접근성)
        if (modalData.previouslyFocused && modalData.previouslyFocused.focus) {
            setTimeout(() => {
                modalData.previouslyFocused.focus();
            }, 100);
        }
    },

    closeTop() {
        if (this.stack.length === 0) return;
        const topModal = this.stack[this.stack.length - 1];
        if (topModal.closeOnOverlay !== false) {
            this.close(topModal.id);
        }
    },

    closeAll() {
        while (this.stack.length > 0) {
            this.close(this.stack[0].id);
        }
    },

    // 확인 대화상자
    confirm(message, onConfirm, onCancel) {
        return this.open({
            title: '확인',
            content: `<p>${message}</p>`,
            size: 'small',
            buttons: [
                {
                    label: '취소',
                    class: 'btn-secondary',
                    onClick: (manager, id) => {
                        if (onCancel) onCancel();
                        manager.close(id);
                    }
                },
                {
                    label: '확인',
                    class: 'btn-primary',
                    onClick: (manager, id) => {
                        if (onConfirm) onConfirm();
                        manager.close(id);
                    }
                }
            ]
        });
    },

    // 알림 대화상자
    alert(message, onOk) {
        return this.open({
            title: '알림',
            content: `<p>${message}</p>`,
            size: 'small',
            buttons: [
                {
                    label: '확인',
                    class: 'btn-primary',
                    onClick: (manager, id) => {
                        if (onOk) onOk();
                        manager.close(id);
                    }
                }
            ]
        });
    }
};

// ============================================
// PROGRESS BAR COMPONENT
// ============================================
const ProgressBar = {
    /**
     * 진행바 생성
     * @param {Object} options
     * @returns {HTMLElement}
     */
    create(options = {}) {
        const {
            value = 0,
            max = 100,
            showLabel = true,
            labelFormat = 'percent', // 'percent' | 'value' | 'custom'
            customLabel = null,
            color = 'accent', // 'accent' | 'success' | 'warning' | 'danger' | 커스텀 색상
            size = 'medium', // 'small' | 'medium' | 'large'
            animated = false,
            striped = false
        } = options;

        const container = document.createElement('div');
        container.className = `ui-progress ui-progress-${size}`;
        // 접근성: progressbar role과 aria 속성
        container.setAttribute('role', 'progressbar');
        container.setAttribute('aria-valuemin', '0');
        container.setAttribute('aria-valuemax', String(max));
        container.setAttribute('aria-valuenow', String(value));

        const bar = document.createElement('div');
        bar.className = 'progress-bar';
        bar.setAttribute('aria-hidden', 'true'); // 시각적 표현만 담당
        if (animated) bar.classList.add('animated');
        if (striped) bar.classList.add('striped');

        // 색상 적용
        if (['accent', 'success', 'warning', 'danger'].includes(color)) {
            bar.classList.add(`progress-${color}`);
        } else {
            bar.style.backgroundColor = color;
        }

        const label = document.createElement('span');
        label.className = 'progress-label';

        container.appendChild(bar);
        if (showLabel) container.appendChild(label);

        // 데이터 저장
        container._progressData = { value, max, showLabel, labelFormat, customLabel };

        // 초기값 설정
        this.update(container, value, max);

        return container;
    },

    update(container, value, max) {
        if (!container || !container._progressData) return;

        const data = container._progressData;
        data.value = value;
        if (max !== undefined) data.max = max;

        const percent = Math.min(100, Math.max(0, (data.value / data.max) * 100));
        const bar = container.querySelector('.progress-bar');
        const label = container.querySelector('.progress-label');

        bar.style.width = `${percent}%`;

        // 접근성: aria 값 업데이트
        container.setAttribute('aria-valuenow', String(data.value));
        container.setAttribute('aria-valuemax', String(data.max));

        if (label && data.showLabel) {
            if (data.customLabel) {
                label.textContent = data.customLabel(data.value, data.max);
            } else if (data.labelFormat === 'value') {
                label.textContent = `${data.value}/${data.max}`;
            } else {
                label.textContent = `${Math.round(percent)}%`;
            }
        }
    },

    // 색상 변경
    setColor(container, color) {
        const bar = container.querySelector('.progress-bar');
        bar.className = 'progress-bar';
        if (container._progressData.animated) bar.classList.add('animated');
        if (container._progressData.striped) bar.classList.add('striped');

        if (['accent', 'success', 'warning', 'danger'].includes(color)) {
            bar.classList.add(`progress-${color}`);
        } else {
            bar.style.backgroundColor = color;
        }
    }
};

// ============================================
// LOADING INDICATOR
// ============================================
const Loading = {
    overlay: null,

    init() {
        this.overlay = document.createElement('div');
        this.overlay.className = 'ui-loading-overlay';
        // 접근성: 로딩 상태를 스크린 리더에 알림
        this.overlay.setAttribute('role', 'alert');
        this.overlay.setAttribute('aria-live', 'assertive');
        this.overlay.setAttribute('aria-busy', 'false');
        this.overlay.innerHTML = `
            <div class="loading-spinner" aria-hidden="true"></div>
            <div class="loading-text" id="loading-status">Loading...</div>
        `;
        this.overlay.setAttribute('aria-describedby', 'loading-status');
        document.body.appendChild(this.overlay);

        console.log('Loading indicator initialized');
    },

    show(text = 'Loading...') {
        this.overlay.querySelector('.loading-text').textContent = text;
        this.overlay.setAttribute('aria-busy', 'true');
        this.overlay.classList.add('visible');
    },

    hide() {
        this.overlay.setAttribute('aria-busy', 'false');
        this.overlay.classList.remove('visible');
    },

    // 비동기 작업 래퍼
    async wrap(promise, text = 'Loading...') {
        this.show(text);
        try {
            return await promise;
        } finally {
            this.hide();
        }
    }
};

// ============================================
// UI COMPONENTS 초기화
// ============================================
const UIComponents = {
    initialized: false,

    init() {
        if (this.initialized) return;

        Tooltip.init();
        Toast.init();
        ModalManager.init();
        Loading.init();

        this.initialized = true;
        console.log('UI Components system initialized');
    }
};

// 전역 노출
window.Tooltip = Tooltip;
window.Toast = Toast;
window.ModalManager = ModalManager;
window.ProgressBar = ProgressBar;
window.Loading = Loading;
window.UIComponents = UIComponents;

// DOM 로드 시 자동 초기화
document.addEventListener('DOMContentLoaded', () => {
    UIComponents.init();
});
