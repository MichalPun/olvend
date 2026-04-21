(function () {
  const currentPath = window.location.pathname.split("/").pop() || "dashboard.html";
  const SIDEBAR_ORDER_KEY = "olvendSidebarOrderV2";
  const RELEASE_NOTES_KEY = "olvendSeenReleaseNotes";
  const APP_VERSION = "OLVEND 1.2";
  const MIN_RELEASE_ANNOUNCEMENT = "1.2";
  const RELEASE_NOTES = {
    "1.2": {
      title: "Nová verze 1.2",
      subtitle: "Rozhraní jsme pročistili tak, aby se dalo rychleji najít to důležité a jednotlivé moduly nepůsobily přehlceně.",
      items: [
        "Stránky nově zvýrazňují hlavní akci a sekundární bloky se dají sbalit, takže nahoře zůstává méně rušivých prvků.",
        "Provoz, Servis a Vozový park mají kompaktnější filtry a rozšířené přehledy až na druhé úrovni.",
        "HR je víc task-first: rychlé ovládání je nahoře a doplňkové operace jsou méně rozptýlené.",
        "Mobilní zobrazení zůstává zachované a sbalitelné sekce fungují i na menších displejích."
      ]
    }
  };

  const pageMeta = {
    "dashboard.html": {
      currentLabel: "Dashboard",
      activeKey: "dashboard",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "attendance.html": {
      currentLabel: "Moje směna",
      activeKey: "shift",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "warehouses.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "hr.html": {
      currentLabel: "HR",
      activeKey: "hr",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "operations.html": {
      currentLabel: "Provoz",
      activeKey: "operations",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "routes.html": {
      currentLabel: "Trasy",
      activeKey: "routes",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "routes-create.html": {
      currentLabel: "Vytvořit trasu",
      activeKey: "routes",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "routes-history.html": {
      currentLabel: "Vytvořené trasy",
      activeKey: "routes",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "service-requests.html": {
      currentLabel: "Servis",
      activeKey: "service",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "machines.html": {
      currentLabel: "Stroje / Automaty",
      activeKey: "machines",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "inventory.html": {
      currentLabel: "Inventář / zásoby",
      activeKey: "inventory",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "hr-planning.html": {
      currentLabel: "Plán směn",
      activeKey: "hr",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "reporty.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "report-attendance.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "report-shift-overview.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "manager-review.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "settings.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "employees.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "vehicles.html": {
      currentLabel: "Vozový park",
      activeKey: "fleet",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "company.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    }
  };

  const meta = pageMeta[currentPath] || pageMeta["dashboard.html"];

  const navItems = [
    { key: "dashboard", href: "dashboard.html", label: "Dashboard" },
    { key: "shift", href: "attendance.html", label: "Moje směna" },
    { key: "machines", href: "machines.html", label: "Stroje / Automaty" },
    { key: "inventory", href: "inventory.html", label: "Inventář / zásoby" },
    { key: "service", href: "service-requests.html", label: "Servis" },
    { key: "operations", href: "operations.html", label: "Provoz" },
    { key: "routes", href: "routes.html", label: "Trasy" },
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

      const defaultKeys = navItems.map((item) => item.key);
      const knownKeys = order.filter((key) => defaultKeys.includes(key));
      const normalizedKeys = [...knownKeys];

      defaultKeys.forEach((key, defaultIndex) => {
        if (normalizedKeys.includes(key)) return;

        const nextKnownKey = defaultKeys
          .slice(defaultIndex + 1)
          .find((candidateKey) => normalizedKeys.includes(candidateKey));

        if (!nextKnownKey) {
          normalizedKeys.push(key);
          return;
        }

        const insertIndex = normalizedKeys.indexOf(nextKnownKey);
        normalizedKeys.splice(insertIndex, 0, key);
      });

      if (JSON.stringify(order) !== JSON.stringify(normalizedKeys)) {
        saveSidebarOrder(normalizedKeys);
      }

      const byKey = new Map(navItems.map((item) => [item.key, item]));
      return normalizedKeys.map((key) => byKey.get(key)).filter(Boolean);
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
      .filter((item) => !item.soon || ["dashboard", "shift", "machines", "inventory", "service", "fleet", "hr", "settings"].includes(item.key))
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
      .sidebar {
        display: flex;
        flex-direction: column;
        padding: 24px 18px;
        border-right: 1px solid rgba(255,255,255,0.08);
        background: rgba(12,13,17,0.92);
        backdrop-filter: blur(14px);
      }

      .brand {
        padding: 8px 10px 22px;
      }

      .brand-logo {
        font-size: 32px;
        font-weight: 800;
        letter-spacing: -0.05em;
        line-height: 1;
        margin-bottom: 8px;
        color: #fff;
      }

      .brand-logo span {
        color: #d5101a;
      }

      .brand-subtitle {
        color: #a5a8b2;
        font-size: 13px;
        line-height: 1.5;
      }

      .global-nav-group,
      .nav-group {
        margin-bottom: 24px;
      }

      .global-nav-title,
      .nav-title {
        margin: 0 0 10px;
        color: #a5a8b2;
        font-size: 12px;
        font-weight: 800;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        padding: 0 10px;
      }

      .nav {
        display: grid;
        gap: 8px;
      }

      .nav a {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 12px 14px;
        border-radius: 14px;
        text-decoration: none;
        color: #fff;
        font-size: 14px;
        font-weight: 600;
        transition: 0.2s ease;
        border: 1px solid transparent;
      }

      .nav a:hover {
        background: rgba(255,255,255,0.05);
      }

      .nav a.active {
        background: rgba(213,16,26,0.14);
        border-color: rgba(213,16,26,0.22);
      }

      .nav-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: rgba(255,255,255,0.28);
        flex: 0 0 8px;
      }

      .nav a.active .nav-dot {
        background: #d5101a;
        box-shadow: 0 0 12px rgba(213,16,26,0.7);
      }

      .nav-status {
        margin-left: auto;
        font-size: 10px;
        font-weight: 800;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        padding: 5px 7px;
        border-radius: 999px;
        background: rgba(255,255,255,0.06);
        color: #979daa;
        border: 1px solid rgba(255,255,255,0.06);
      }

      .sidebar-bottom {
        margin-top: auto;
        padding: 14px 10px 6px;
      }

      .version-box {
        padding: 14px;
        border-radius: 16px;
        background: rgba(255,255,255,0.04);
        border: 1px solid rgba(255,255,255,0.08);
      }

      .version-label {
        color: #7d818c;
        font-size: 11px;
        text-transform: uppercase;
        letter-spacing: 0.1em;
        margin-bottom: 6px;
      }

      .version-value {
        font-size: 15px;
        font-weight: 700;
        color: #fff;
        margin-bottom: 4px;
      }

      .version-note {
        color: #a5a8b2;
        font-size: 12px;
        line-height: 1.5;
      }

      .mobile-nav-shell {
        display: none;
      }

      .mobile-nav-toggle {
        width: 100%;
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
        padding: 12px 14px;
        border-radius: 18px;
        background: rgba(12,13,17,0.92);
        border: 1px solid rgba(255,255,255,0.08);
        backdrop-filter: blur(14px);
        color: #fff;
        cursor: pointer;
      }

      .mobile-nav-toggle-left {
        display: flex;
        flex-direction: column;
        gap: 3px;
        text-align: left;
      }

      .mobile-nav-label {
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: #a5a8b2;
      }

      .mobile-nav-current {
        font-size: 14px;
        font-weight: 700;
        color: #fff;
      }

      .mobile-nav-icon {
        width: 10px;
        height: 10px;
        border-right: 2px solid rgba(255,255,255,0.72);
        border-bottom: 2px solid rgba(255,255,255,0.72);
        transform: rotate(45deg);
        transition: transform 0.2s ease;
        margin-right: 4px;
        flex: 0 0 10px;
      }

      .mobile-nav-shell.open .mobile-nav-icon {
        transform: rotate(-135deg);
        margin-top: 6px;
      }

      .mobile-nav-panel {
        display: none;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 8px;
        margin-top: 8px;
        padding: 10px;
        border-radius: 18px;
        background: rgba(12,13,17,0.96);
        border: 1px solid rgba(255,255,255,0.08);
        backdrop-filter: blur(14px);
      }

      .mobile-nav-shell.open .mobile-nav-panel {
        display: grid;
      }

      .mobile-nav-panel a {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 10px 12px;
        border-radius: 12px;
        text-decoration: none;
        color: #fff;
        font-size: 12px;
        font-weight: 700;
        border: 1px solid rgba(255,255,255,0.06);
        background: rgba(255,255,255,0.04);
        white-space: nowrap;
      }

      .mobile-nav-panel a.active {
        background: rgba(213,16,26,0.14);
        border-color: rgba(213,16,26,0.28);
      }

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

      .release-note {
        margin-top: 14px;
        color: #a5a8b2;
        font-size: 13px;
        line-height: 1.55;
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

      @media (max-width: 980px) {
        .sidebar {
          display: none;
        }

        .mobile-nav-shell {
          display: block;
          position: sticky;
          top: 0;
          z-index: 20;
          margin-bottom: 14px;
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
            <div class="release-note">
              Okno se zobrazí jen jednou na zařízení. Pak už můžeš rovnou pokračovat do práce.
            </div>
          </div>
          <div class="release-footer">
            <button class="release-btn primary" type="button" id="releaseConfirmBtn">Začít používat ${version}</button>
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
    if (!backdrop || !confirmBtn) return;

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

  try {
    setupReleaseNotes();
  } catch (error) {
    console.error("Release notes init failed:", error);
  }
})();
