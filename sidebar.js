(function () {
  const currentPath = window.location.pathname.split("/").pop() || "dashboard.html";
  const SIDEBAR_ORDER_KEY = "olvendSidebarOrder";
  const RELEASE_NOTES_KEY = "olvendSeenReleaseNotes";
  const MIN_RELEASE_ANNOUNCEMENT = "1.1";
  const RELEASE_NOTES = {
    "1.1": {
      title: "Nová verze 1.1",
      subtitle: "Dnes jsme posunuli OLVEND o kus dál. Tady je to hlavní, co je nově připravené.",
      items: [
        "Moje směna je nově čistší a lépe čitelná na telefonu.",
        "HR má samostatný planner směn a rychlejší vstupy do práce s týmem.",
        "Přibyl přehled směn s plánogramem, fondy a kontrolními upozorněními.",
        "Můj profil nově obsahuje docházku a dostupnost na dalších 14 dní.",
        "Sidebar i HR sekce si můžeš přeskládat podle toho, co používáš nejvíc."
      ]
    }
  };

  const pageMeta = {
    "dashboard.html": {
      currentLabel: "Dashboard",
      activeKey: "dashboard",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "attendance.html": {
      currentLabel: "Moje směna",
      activeKey: "shift",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "warehouses.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "hr.html": {
      currentLabel: "HR",
      activeKey: "hr",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "hr-planning.html": {
      currentLabel: "Plán směn",
      activeKey: "hr",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "reporty.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "report-attendance.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "settings.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "employees.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "vehicles.html": {
      currentLabel: "Vozový park",
      activeKey: "fleet",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    },
    "company.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Aktuální verze",
      versionValue: "OLVEND 1.0",
      versionNote: ""
    }
  };

  const meta = pageMeta[currentPath] || pageMeta["dashboard.html"];

  const navItems = [
    { key: "dashboard", href: "dashboard.html", label: "Dashboard" },
    { key: "shift", href: "attendance.html", label: "Moje směna" },
    { key: "service", href: "#", label: "Servis", soon: true },
    { key: "operations", href: "#", label: "Provoz", soon: true },
    { key: "fleet", href: "vehicles.html", label: "Vozový park" },
    { key: "hr", href: "hr.html", label: "HR" },
    { key: "reporty", href: "reporty.html", label: "Reporty" },
    { key: "settings", href: "settings.html", label: "Nastavení" }
  ];

  function getOrderedNavItems() {
    const raw = localStorage.getItem(SIDEBAR_ORDER_KEY);
    if (!raw) return navItems;

    try {
      const order = JSON.parse(raw);
      if (!Array.isArray(order) || !order.length) return navItems;

      const byKey = new Map(navItems.map((item) => [item.key, item]));
      const ordered = [];

      order.forEach((key) => {
        const item = byKey.get(key);
        if (item) {
          ordered.push(item);
          byKey.delete(key);
        }
      });

      navItems.forEach((item) => {
        if (byKey.has(item.key)) ordered.push(item);
      });

      return ordered;
    } catch (error) {
      console.error(error);
      return navItems;
    }
  }

  function saveSidebarOrder(keys) {
    localStorage.setItem(SIDEBAR_ORDER_KEY, JSON.stringify(keys));
  }

  function extractVersionNumber(value) {
    const match = String(value || "").match(/(\d+\.\d+)/);
    return match ? match[1] : "";
  }

  function compareVersions(a, b) {
    const aParts = String(a || "").split(".").map((part) => Number(part || 0));
    const bParts = String(b || "").split(".").map((part) => Number(part || 0));
    const length = Math.max(aParts.length, bParts.length);

    for (let index = 0; index < length; index += 1) {
      const diff = (aParts[index] || 0) - (bParts[index] || 0);
      if (diff !== 0) return diff;
    }

    return 0;
  }

  function renderDesktopNav() {
    return getOrderedNavItems().map((item) => {
      const activeClass = item.key === meta.activeKey ? "active" : "";
      const status = item.soon ? '<span class="nav-status">Brzy</span>' : "";
      return `
        <a href="${item.href}" class="${activeClass}" data-nav-key="${item.key}" draggable="true">
          <span class="nav-dot"></span>
          <span>${item.label}</span>
          ${status}
        </a>
      `;
    }).join("");
  }

  function renderMobileLinks() {
    return getOrderedNavItems()
      .filter((item) => !item.soon || ["dashboard", "shift", "fleet", "hr", "settings"].includes(item.key))
      .map((item) => {
        const activeClass = item.key === meta.activeKey ? "active" : "";
        return `<a href="${item.href}" class="${activeClass}">${item.label}</a>`;
      })
      .join("");
  }

  function renderSidebar() {
    return `
      <div class="brand">
        <div class="brand-logo">OL<span>VEND</span></div>
        <div class="brand-subtitle">Interní servisní systém pro správu vendingového provozu OLMIKA.</div>
      </div>

      <div class="nav-group global-nav-group">
        <div class="nav-title global-nav-title">Hlavní menu</div>
        <div class="global-nav-note">Pořadí si můžeš přeskládat tahem.</div>
        <nav class="nav">
          ${renderDesktopNav()}
        </nav>
      </div>

      <div class="sidebar-bottom">
        <div class="version-box">
          <div class="version-label">${meta.versionLabel}</div>
          <div class="version-value">${meta.versionValue}</div>
          ${meta.versionNote ? `<div class="version-note">${meta.versionNote}</div>` : ""}
        </div>
      </div>
    `;
  }

  function renderMobileShell() {
    return `
      <button class="mobile-nav-toggle" id="mobileNavToggle" type="button" aria-expanded="false" aria-controls="mobileNavPanel">
        <span class="mobile-nav-toggle-left">
          <span class="mobile-nav-label">Hlavní menu</span>
          <span class="mobile-nav-current">${meta.currentLabel}</span>
        </span>
        <span class="mobile-nav-icon"></span>
      </button>

      <nav class="mobile-nav-panel" id="mobileNavPanel" aria-label="Hlavní menu">
        ${renderMobileLinks()}
      </nav>
    `;
  }

  function renderMobileGlobalNav() {
    return renderMobileLinks();
  }

  function injectSidebarReorderStyles() {
    if (document.getElementById("olvendSidebarReorderStyles")) return;

    const style = document.createElement("style");
    style.id = "olvendSidebarReorderStyles";
    style.textContent = `
      .global-nav-note {
        margin: -4px 0 12px;
        color: #7d818c;
        font-size: 12px;
        line-height: 1.45;
        padding: 0 10px;
      }

      .nav a[draggable="true"] {
        cursor: grab;
      }

      .nav a.dragging {
        opacity: 0.58;
        border-color: rgba(213, 16, 26, 0.24);
      }

      .nav a.drag-target {
        background: rgba(255,255,255,0.05);
        border-color: rgba(255,255,255,0.14);
      }

      .release-backdrop {
        position: fixed;
        inset: 0;
        display: none;
        align-items: center;
        justify-content: center;
        padding: 20px;
        background: rgba(3, 4, 8, 0.74);
        backdrop-filter: blur(10px);
        z-index: 1200;
      }

      .release-backdrop.show {
        display: flex;
      }

      .release-card {
        width: min(100%, 560px);
        background: rgba(16, 17, 22, 0.98);
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 24px;
        box-shadow: 0 24px 70px rgba(0,0,0,0.42);
        overflow: hidden;
      }

      .release-head {
        padding: 22px 22px 16px;
        border-bottom: 1px solid rgba(255,255,255,0.08);
      }

      .release-kicker {
        display: inline-flex;
        align-items: center;
        padding: 7px 10px;
        border-radius: 999px;
        background: rgba(213,16,26,0.16);
        border: 1px solid rgba(213,16,26,0.22);
        color: #fff;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        margin-bottom: 12px;
      }

      .release-head h2 {
        margin: 0 0 8px;
        color: #fff;
        font-size: 28px;
        line-height: 1.05;
      }

      .release-head p {
        margin: 0;
        color: #a5a8b2;
        font-size: 14px;
        line-height: 1.65;
      }

      .release-body {
        padding: 18px 22px 22px;
      }

      .release-list {
        display: grid;
        gap: 10px;
        margin: 0;
        padding: 0;
        list-style: none;
      }

      .release-list li {
        padding: 14px 14px 14px 42px;
        border-radius: 16px;
        background: rgba(255,255,255,0.03);
        border: 1px solid rgba(255,255,255,0.06);
        color: #f4f4f6;
        font-size: 14px;
        line-height: 1.55;
        position: relative;
      }

      .release-list li::before {
        content: "";
        position: absolute;
        left: 15px;
        top: 18px;
        width: 12px;
        height: 12px;
        border-radius: 999px;
        background: #d5101a;
        box-shadow: 0 0 14px rgba(213,16,26,0.45);
      }

      .release-footer {
        display: flex;
        justify-content: flex-end;
        gap: 10px;
        padding: 0 22px 22px;
      }

      .release-btn {
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 14px;
        padding: 12px 16px;
        cursor: pointer;
        font-size: 14px;
        font-weight: 800;
        transition: 0.2s ease;
      }

      .release-btn.secondary {
        background: rgba(255,255,255,0.05);
        color: #fff;
      }

      .release-btn.secondary:hover {
        background: rgba(255,255,255,0.1);
      }

      .release-btn.primary {
        background: #d5101a;
        color: #fff;
      }

      .release-btn.primary:hover {
        background: #b90d16;
      }

      @media (max-width: 640px) {
        .release-backdrop {
          padding: 0;
          align-items: flex-end;
        }

        .release-card {
          width: 100%;
          border-radius: 24px 24px 0 0;
        }

        .release-head h2 {
          font-size: 24px;
        }

        .release-footer {
          flex-direction: column;
        }

        .release-btn {
          width: 100%;
        }
      }
    `;

    document.head.appendChild(style);
  }

  function setupSidebarReordering() {
    const nav = document.querySelector(".global-nav-group .nav");
    if (!nav) return;

    let draggedItem = null;
    const items = [...nav.querySelectorAll("a[data-nav-key]")];

    const clearDragState = () => {
      items.forEach((item) => item.classList.remove("dragging", "drag-target"));
    };

    items.forEach((item) => {
      item.addEventListener("dragstart", () => {
        draggedItem = item;
        item.classList.add("dragging");
      });

      item.addEventListener("dragover", (event) => {
        if (!draggedItem || draggedItem === item) return;
        event.preventDefault();
        items.forEach((entry) => entry.classList.remove("drag-target"));
        item.classList.add("drag-target");
      });

      item.addEventListener("drop", (event) => {
        if (!draggedItem || draggedItem === item) return;
        event.preventDefault();

        const rect = item.getBoundingClientRect();
        const shouldInsertAfter = event.clientY > rect.top + (rect.height / 2);

        if (shouldInsertAfter) {
          nav.insertBefore(draggedItem, item.nextSibling);
        } else {
          nav.insertBefore(draggedItem, item);
        }

        const nextOrder = [...nav.querySelectorAll("a[data-nav-key]")].map((entry) => entry.dataset.navKey);
        saveSidebarOrder(nextOrder);
        clearDragState();
      });

      item.addEventListener("dragend", () => {
        draggedItem = null;
        clearDragState();
      });
    });

    nav.addEventListener("dragover", (event) => {
      if (draggedItem) event.preventDefault();
    });
  }

  function renderReleaseModal(version, notes) {
    return `
      <div class="release-backdrop" id="releaseBackdrop" aria-hidden="true">
        <div class="release-card" role="dialog" aria-modal="true" aria-labelledby="releaseTitle">
          <div class="release-head">
            <div class="release-kicker">Co je nového</div>
            <h2 id="releaseTitle">${notes.title}</h2>
            <p>${notes.subtitle}</p>
          </div>
          <div class="release-body">
            <ul class="release-list">
              ${notes.items.map((item) => `<li>${item}</li>`).join("")}
            </ul>
          </div>
          <div class="release-footer">
            <button class="release-btn secondary" type="button" id="releaseCloseLater">Zavřít</button>
            <button class="release-btn primary" type="button" id="releaseConfirmBtn">Rozumím</button>
          </div>
        </div>
      </div>
    `;
  }

  function setupReleaseNotes() {
    const currentVersion = extractVersionNumber(meta.versionValue);
    if (!currentVersion) return;
    if (compareVersions(currentVersion, MIN_RELEASE_ANNOUNCEMENT) < 0) return;

    const notes = RELEASE_NOTES[currentVersion];
    if (!notes) return;

    const seenVersion = localStorage.getItem(RELEASE_NOTES_KEY);
    if (seenVersion === currentVersion) return;

    const wrapper = document.createElement("div");
    wrapper.innerHTML = renderReleaseModal(currentVersion, notes);
    document.body.appendChild(wrapper.firstElementChild);

    const backdrop = document.getElementById("releaseBackdrop");
    const confirmBtn = document.getElementById("releaseConfirmBtn");
    const closeBtn = document.getElementById("releaseCloseLater");
    if (!backdrop || !confirmBtn || !closeBtn) return;

    const closeModal = (markSeen) => {
      if (markSeen) {
        localStorage.setItem(RELEASE_NOTES_KEY, currentVersion);
      }
      backdrop.classList.remove("show");
      backdrop.setAttribute("aria-hidden", "true");
      window.setTimeout(() => {
        backdrop.remove();
      }, 160);
    };

    confirmBtn.addEventListener("click", () => closeModal(true));
    closeBtn.addEventListener("click", () => closeModal(true));
    backdrop.addEventListener("click", (event) => {
      if (event.target === backdrop) {
        closeModal(true);
      }
    });

    document.addEventListener("keydown", function handleReleaseEscape(event) {
      if (event.key === "Escape") {
        closeModal(true);
        document.removeEventListener("keydown", handleReleaseEscape);
      }
    });

    requestAnimationFrame(() => {
      backdrop.classList.add("show");
      backdrop.setAttribute("aria-hidden", "false");
    });
  }

  const sidebar = document.querySelector(".sidebar");
  if (sidebar) {
    injectSidebarReorderStyles();
    sidebar.innerHTML = renderSidebar();
    setupSidebarReordering();
  }

  const mobileShell = document.querySelector(".mobile-nav-shell");
  if (mobileShell) {
    mobileShell.innerHTML = renderMobileShell();
  }

  const mobileGlobalNav = document.querySelector(".mobile-global-nav");
  if (mobileGlobalNav) {
    mobileGlobalNav.innerHTML = renderMobileGlobalNav();
  }

  injectSidebarReorderStyles();
  setupReleaseNotes();
})();
