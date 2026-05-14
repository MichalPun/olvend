(function () {
  const currentPath = window.location.pathname.split("/").pop() || "dashboard.html";
  const currentPathWithQuery = `${currentPath}${window.location.search || ""}`;
  const RELEASE_NOTES_KEY = "olvendSeenReleaseNotes";
  const APP_THEME_KEY = "olvendThemePreference";
  const NAV_COLLAPSE_KEY = "olvendCollapsedNavGroups";
  const APP_VERSION = "OLVEND 1.42";
  const MIN_RELEASE_ANNOUNCEMENT = "1.42";
  const RELEASE_NOTES = {
    "1.42": {
      title: "Nová verze 1.42",
      subtitle: "Tahleta verze dorovnává kritické provozní kroky, hlavně Moje směna v mobilu, ukončení směny a stabilitu hlavních přehledů.",
      items: [
        "Moje směna v mobilu je stabilnější: lépe funguje ukončení směny, konečné km, tankování i kontrolní krok vykládky.",
        "Ukončení směny už nepadá na vedlejší aktualizaci vozidla a lépe ukazuje konkrétní důvod, pokud něco skutečně chybí.",
        "Dashboard, servis a další přehledy byly dorovnané tak, aby nepadaly na chybějících sloupcích nebo starších datech.",
        "Spodní mobilní navigace je znovu zjednodušená podle role, takže není přeplněná a zůstává použitelná v provozu.",
        "Verze 1.42 je hlavně stabilizační vydání pro každodenní práci operátorů i vedení."
      ]
    }
  };

  const pageMeta = {
    "dashboard.html": {
      currentLabel: "Nástěnka",
      activeKey: "home",
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
    "noticeboard.html": {
      currentLabel: "Nástěnka",
      activeKey: "home",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "warehouses.html": {
      currentLabel: "Sklady",
      activeKey: "warehouses",
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
    "approval-center.html": {
      currentLabel: "Schvalování",
      activeKey: "approvals",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "tasks.html": {
      currentLabel: "Manažerský blok",
      activeKey: "tasks",
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
      currentLabel: "Servisní požadavky",
      activeKey: "service-requests",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "technical-jobs.html": {
      currentLabel: "Technické zásahy",
      activeKey: "technical-jobs",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "machines.html": {
      currentLabel: "Stroje",
      activeKey: "machines",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "machine-qr-print.html": {
      currentLabel: "QR štítky",
      activeKey: "qr-labels",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "machine-qr.html": {
      currentLabel: "QR servis",
      activeKey: "qr-service",
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
    "purchases.html": {
      currentLabel: "Nákupy",
      activeKey: "purchases-overview",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "suppliers.html": {
      currentLabel: "Dodavatelé",
      activeKey: "suppliers",
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
    "report-vehicles.html": {
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

  const navGroups = [
    {
      key: "today",
      title: "Dnes",
      items: [
        { key: "home", href: "dashboard.html", label: "Nástěnka" },
        { key: "shift", href: "attendance.html", label: "Moje směna" }
      ]
    },
    {
      key: "operations",
      title: "Provoz",
      items: [
        {
          key: "technical-management",
          href: "technical-jobs.html",
          label: "Technické zásahy",
          children: [
            { key: "technical-jobs", href: "technical-jobs.html", label: "Technické karty" },
            { key: "service-requests", href: "service-requests.html", label: "Servisní požadavky" },
            { key: "installations", href: "technical-jobs.html?tab=installation", label: "Instalace" },
            { key: "deinstallations", href: "technical-jobs.html?tab=deinstallation", label: "Deinstalace" },
            { key: "transfers", href: "technical-jobs.html?tab=transfer", label: "Přesuny" },
            { key: "revisions", href: "technical-jobs.html?tab=revision", label: "Revize" },
            { key: "service-cards", href: "technical-jobs.html?tab=service", label: "Servisní karty" },
            { key: "qr-labels", href: "machine-qr-print.html", label: "QR štítky" }
          ]
        },
        {
          key: "machines-management",
          href: "machines.html",
          label: "Stroje",
          children: [
            { key: "machines", href: "machines.html", label: "Všechny stroje" },
            { key: "machines-placed", href: "machines.html?placement=placed", label: "Umístěné automaty" },
            { key: "machines-storage", href: "machines.html?placement=storage", label: "Automaty ve skladu" }
          ]
        },
        {
          key: "logistics-management",
          href: "routes.html",
          label: "Logistika",
          children: [
            { key: "operations", href: "operations.html", label: "Lokality" },
            { key: "routes", href: "routes.html", label: "Trasy" },
            { key: "routes-create", href: "routes-create.html", label: "Vytvořit trasu" },
            { key: "routes-history", href: "routes-history.html", label: "Historie tras" },
            { key: "fleet", href: "vehicles.html", label: "Vozový park" }
          ]
        },
        {
          key: "stock-management",
          href: "inventory.html",
          label: "Skladové hospodářství",
          children: [
            { key: "purchases", href: "purchases.html?view=received", label: "Přijaté faktury" },
            { key: "sales-invoices", href: "purchases.html?view=issued", label: "Vystavené faktury", soon: true },
            { key: "inventory", href: "inventory.html", label: "Zásoby" },
            { key: "purchases-overview", href: "purchases.html", label: "Nákupy a příjmy" },
            { key: "suppliers", href: "suppliers.html", label: "Dodavatelé" }
          ]
        }
      ]
    },
    {
      key: "management",
      title: "Řízení",
      items: [
        { key: "approvals", href: "approval-center.html", label: "Schvalování" },
        { key: "hr", href: "hr.html", label: "HR" },
        { key: "tasks", href: "tasks.html", label: "Manažerský blok" },
        { key: "reporty", href: "reporty.html", label: "Reporty" },
        { key: "settings", href: "settings.html", label: "Nastavení" }
      ]
    }
  ];

  function flattenNavItems(items) {
    return items.flatMap((item) => [item, ...(item.children ? flattenNavItems(item.children) : [])]);
  }

  const navItems = navGroups.flatMap((group) => flattenNavItems(group.items));

  function getStoredThemePreference() {
    const stored = localStorage.getItem(APP_THEME_KEY);
    if (stored === "light" || stored === "dark" || stored === "auto") return stored;
    return "auto";
  }

  function resolveTheme(preference) {
    if (preference === "light" || preference === "dark") return preference;
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }

  function updateThemeMeta(theme) {
    const metaTheme = document.querySelector('meta[name="theme-color"]');
    if (metaTheme) {
      metaTheme.setAttribute("content", theme === "light" ? "#f4f5f7" : "#0b0b0d");
    }
  }

  function applyTheme(preference, options = {}) {
    const nextPreference = preference === "light" || preference === "dark" || preference === "auto"
      ? preference
      : "auto";
    const resolvedTheme = resolveTheme(nextPreference);

    document.documentElement.dataset.olvendTheme = resolvedTheme;
    document.documentElement.dataset.olvendThemePreference = nextPreference;
    document.documentElement.style.colorScheme = resolvedTheme;
    updateThemeMeta(resolvedTheme);

    if (!options.skipPersist) {
      localStorage.setItem(APP_THEME_KEY, nextPreference);
    }

    if (!options.skipEvent) {
      document.dispatchEvent(new CustomEvent("olvend:themechange", {
        detail: { preference: nextPreference, theme: resolvedTheme }
      }));
    }

    return { preference: nextPreference, theme: resolvedTheme };
  }

  function syncAutoThemeFromSystem() {
    if (getStoredThemePreference() === "auto") {
      applyTheme("auto", { skipPersist: true });
    }
  }

  function initTheme() {
    const preference = getStoredThemePreference();
    applyTheme(preference, { skipPersist: true, skipEvent: true });

    if (window.matchMedia) {
      const media = window.matchMedia("(prefers-color-scheme: dark)");
      const handleMediaChange = () => {
        if (getStoredThemePreference() === "auto") {
          applyTheme("auto", { skipPersist: true });
        }
      };

      if (typeof media.addEventListener === "function") {
        media.addEventListener("change", handleMediaChange);
      } else if (typeof media.addListener === "function") {
        media.addListener(handleMediaChange);
      }
    }

    window.addEventListener("pageshow", syncAutoThemeFromSystem);
    window.addEventListener("focus", syncAutoThemeFromSystem);
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) syncAutoThemeFromSystem();
    });
    window.addEventListener("storage", (event) => {
      if (event.key === APP_THEME_KEY) {
        applyTheme(getStoredThemePreference(), { skipPersist: true });
      }
    });

    window.OLVEND_THEME = {
      getPreference: getStoredThemePreference,
      getResolvedTheme: () => document.documentElement.dataset.olvendTheme || resolveTheme(getStoredThemePreference()),
      setPreference(nextPreference) {
        return applyTheme(nextPreference);
      }
    };
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

  function isItemActive(item) {
    const href = String(item.href || "");
    const hrefPath = href.split("?")[0];
    const hasExactQueryMatch = Boolean(window.location.search) && navItems.some((navItem) => String(navItem.href || "") === currentPathWithQuery);
    if (href.includes("?") && href === currentPathWithQuery) return true;
    if (!href.includes("?") && hrefPath && hrefPath === currentPath && !window.location.search) return true;
    if (item.key === meta.activeKey && !hasExactQueryMatch) return true;
    return Array.isArray(item.children) && item.children.some(isItemActive);
  }

  function getCollapsedNavGroups() {
    try {
      const parsed = JSON.parse(localStorage.getItem(NAV_COLLAPSE_KEY) || "[]");
      return new Set(Array.isArray(parsed) ? parsed : []);
    } catch (error) {
      return new Set();
    }
  }

  function setNavGroupCollapsed(key, collapsed) {
    const collapsedGroups = getCollapsedNavGroups();
    if (collapsed) {
      collapsedGroups.add(key);
    } else {
      collapsedGroups.delete(key);
    }
    localStorage.setItem(NAV_COLLAPSE_KEY, JSON.stringify(Array.from(collapsedGroups)));
  }

  function renderNavLinks(items) {
    const collapsedGroups = getCollapsedNavGroups();
    return items.map((item) => {
      const isActive = isItemActive(item);
      const activeClass = isActive ? "active" : "";
      const status = item.soon ? '<span class="nav-status">Brzy</span>' : "";
      const hasChildren = Array.isArray(item.children) && item.children.length;
      const collapsed = hasChildren && collapsedGroups.has(item.key) && !isActive;
      const expanded = hasChildren && !collapsed;
      const childLinks = Array.isArray(item.children) && item.children.length
        ? `<div class="nav-subitems" id="nav-children-${item.key}">${renderNavLinks(item.children)}</div>`
        : "";
      return `
        <div class="nav-item-shell ${hasChildren ? "has-children" : ""} ${collapsed ? "collapsed" : ""}">
          <div class="nav-link-row">
            <a href="${item.href}" class="${activeClass}" data-nav-key="${item.key}">
              <span class="nav-dot"></span>
              <span>${item.label}</span>
              ${status}
            </a>
            ${hasChildren ? `<button class="nav-collapse-toggle" type="button" data-collapse-nav="${item.key}" aria-expanded="${expanded ? "true" : "false"}" aria-controls="nav-children-${item.key}" title="${expanded ? "Sbalit" : "Rozbalit"}"><span></span></button>` : ""}
          </div>
          ${childLinks}
        </div>
      `;
    }).join("");
  }

  function renderDesktopNav() {
    return navGroups.map((group) => `
      <div class="nav-group">
        <div class="nav-title">${group.title}</div>
        <nav class="nav">
          ${renderNavLinks(group.items)}
        </nav>
      </div>
    `).join("");
  }

  function renderMobileLinks() {
    return navGroups.map((group) => {
      const flattenedItems = flattenNavItems(group.items);
      const filteredItems = flattenedItems.filter((item) => !item.soon || ["home", "shift", "machines", "inventory", "purchases", "suppliers", "warehouses", "service", "fleet", "hr", "settings"].includes(item.key));
      if (!filteredItems.length) return "";

      return `
        <div class="mobile-nav-section">
          <div class="mobile-nav-section-title">${group.title}</div>
          <div class="mobile-nav-section-links">
            ${filteredItems.map((item) => {
              const activeClass = isItemActive(item) ? "active" : "";
              return `<a href="${item.href}" class="${activeClass}">${item.label}</a>`;
            }).join("")}
          </div>
        </div>
      `;
    }).join("");
  }

  function renderSidebar() {
    return `
      <div class="brand">
        <div class="brand-logo">OL<span>VEND</span></div>
        <div class="brand-subtitle">Interní servisní systém pro správu vendingového provozu OLMIKA.</div>
      </div>

      <div class="nav-group global-nav-group">
        <div class="nav-title global-nav-title">Hlavní menu</div>
        <div class="global-nav-note">Struktura je nově rozdělená podle toho, co řešíš dnes, v provozu a v řízení.</div>
        ${renderDesktopNav()}
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
    return navItems.map((item) => {
      const activeClass = isItemActive(item) ? "active" : "";
      return `<a href="${item.href}" class="${activeClass}">${item.label}</a>`;
    }).join("");
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

      .nav-item-shell {
        display: grid;
        gap: 6px;
      }

      .nav-link-row {
        display: grid;
        grid-template-columns: minmax(0, 1fr) auto;
        gap: 6px;
        align-items: center;
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

      .nav-collapse-toggle {
        width: 34px;
        height: 34px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        border: 1px solid rgba(255,255,255,0.08);
        border-radius: 12px;
        background: rgba(255,255,255,0.04);
        color: #fff;
        cursor: pointer;
        transition: 0.2s ease;
      }

      .nav-collapse-toggle:hover {
        background: rgba(255,255,255,0.08);
      }

      .nav-collapse-toggle span {
        width: 8px;
        height: 8px;
        border-right: 2px solid currentColor;
        border-bottom: 2px solid currentColor;
        transform: rotate(45deg);
        margin-top: -3px;
        transition: transform 0.2s ease, margin 0.2s ease;
      }

      .nav-item-shell.collapsed .nav-collapse-toggle span {
        transform: rotate(-45deg);
        margin-top: 0;
        margin-left: -2px;
      }

      .nav-subitems {
        display: grid;
        gap: 4px;
        margin: -2px 0 4px 18px;
        padding-left: 12px;
        border-left: 1px solid rgba(255,255,255,0.08);
      }

      .nav-item-shell.collapsed .nav-subitems {
        display: none;
      }

      .nav-subitems a {
        padding: 9px 11px;
        border-radius: 11px;
        font-size: 12px;
        font-weight: 700;
        color: #d7dae0;
      }

      .nav-subitems .nav-dot {
        width: 6px;
        height: 6px;
        flex-basis: 6px;
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
        grid-template-columns: 1fr;
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

      .mobile-nav-section {
        display: grid;
        gap: 8px;
      }

      .mobile-nav-section-title {
        padding: 2px 4px 0;
        color: #7d818c;
        font-size: 11px;
        font-weight: 800;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      .mobile-nav-section-links {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 8px;
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

      :root[data-olvend-theme="light"] body {
        color: #18202a !important;
        background: linear-gradient(135deg, #f7f8fb, #eef2f7, #f8fafc) !important;
      }

      :root[data-olvend-theme="light"] {
        --bg: #f4f5f7 !important;
        --panel: rgba(255,255,255,0.92) !important;
        --panel-2: rgba(255,255,255,0.98) !important;
        --panel-soft: rgba(15,23,42,0.03) !important;
        --border: rgba(15,23,42,0.08) !important;
        --border-strong: rgba(15,23,42,0.14) !important;
        --text: #18202a !important;
        --muted: #667085 !important;
        --soft: #8a94a6 !important;
        --shadow: 0 20px 50px rgba(15,23,42,0.08) !important;
      }

      :root[data-olvend-theme="light"] .sidebar,
      :root[data-olvend-theme="light"] .mobile-nav-toggle,
      :root[data-olvend-theme="light"] .mobile-nav-panel,
      :root[data-olvend-theme="light"] .release-card {
        background: rgba(255,255,255,0.92) !important;
        border-color: rgba(24,32,42,0.08) !important;
        box-shadow: 0 20px 48px rgba(15, 23, 42, 0.08);
      }

      :root[data-olvend-theme="light"] .release-backdrop {
        background: rgba(236, 240, 245, 0.64);
      }

      :root[data-olvend-theme="light"] .brand-logo,
      :root[data-olvend-theme="light"] .nav a,
      :root[data-olvend-theme="light"] .mobile-nav-current,
      :root[data-olvend-theme="light"] .mobile-nav-panel a,
      :root[data-olvend-theme="light"] .release-head h2,
      :root[data-olvend-theme="light"] .release-list li,
      :root[data-olvend-theme="light"] .version-value,
      :root[data-olvend-theme="light"] .title h1,
      :root[data-olvend-theme="light"] .page-header h1,
      :root[data-olvend-theme="light"] .page-header h2,
      :root[data-olvend-theme="light"] .content-top h2,
      :root[data-olvend-theme="light"] .widget-header h2,
      :root[data-olvend-theme="light"] .widget-header h3,
      :root[data-olvend-theme="light"] .section-title,
      :root[data-olvend-theme="light"] .panel-title,
      :root[data-olvend-theme="light"] .modal-title,
      :root[data-olvend-theme="light"] .content-card h3,
      :root[data-olvend-theme="light"] .topbar h1,
      :root[data-olvend-theme="light"] .user-meta strong,
      :root[data-olvend-theme="light"] .device-meta strong,
      :root[data-olvend-theme="light"] th,
      :root[data-olvend-theme="light"] td {
        color: #18202a !important;
      }

      :root[data-olvend-theme="light"] .brand-subtitle,
      :root[data-olvend-theme="light"] .global-nav-title,
      :root[data-olvend-theme="light"] .nav-title,
      :root[data-olvend-theme="light"] .global-nav-note,
      :root[data-olvend-theme="light"] .mobile-nav-label,
      :root[data-olvend-theme="light"] .mobile-nav-section-title,
      :root[data-olvend-theme="light"] .release-head p,
      :root[data-olvend-theme="light"] .release-note,
      :root[data-olvend-theme="light"] .version-label,
      :root[data-olvend-theme="light"] .version-note,
      :root[data-olvend-theme="light"] .title p,
      :root[data-olvend-theme="light"] .page-header p,
      :root[data-olvend-theme="light"] .content-card p,
      :root[data-olvend-theme="light"] .widget-header p,
      :root[data-olvend-theme="light"] .helper-text,
      :root[data-olvend-theme="light"] .field-help,
      :root[data-olvend-theme="light"] .empty-state,
      :root[data-olvend-theme="light"] .empty-copy,
      :root[data-olvend-theme="light"] .user-meta span,
      :root[data-olvend-theme="light"] .device-meta span,
      :root[data-olvend-theme="light"] label,
      :root[data-olvend-theme="light"] .table-note {
        color: #667085 !important;
      }

      :root[data-olvend-theme="light"] .nav a:hover,
      :root[data-olvend-theme="light"] .mobile-nav-panel a,
      :root[data-olvend-theme="light"] .release-list li,
      :root[data-olvend-theme="light"] .version-box,
      :root[data-olvend-theme="light"] .widget,
      :root[data-olvend-theme="light"] .kpi-card,
      :root[data-olvend-theme="light"] .action-card,
      :root[data-olvend-theme="light"] .user-panel,
      :root[data-olvend-theme="light"] .device-panel,
      :root[data-olvend-theme="light"] .page-note,
      :root[data-olvend-theme="light"] .content-card,
      :root[data-olvend-theme="light"] .content-footer,
      :root[data-olvend-theme="light"] .modal-card,
      :root[data-olvend-theme="light"] .modal-shell,
      :root[data-olvend-theme="light"] .panel,
      :root[data-olvend-theme="light"] .panel-shell,
      :root[data-olvend-theme="light"] .surface,
      :root[data-olvend-theme="light"] .sheet,
      :root[data-olvend-theme="light"] .table-shell,
      :root[data-olvend-theme="light"] .summary-card,
      :root[data-olvend-theme="light"] .stat-card,
      :root[data-olvend-theme="light"] .card {
        background: rgba(15, 23, 42, 0.03) !important;
        border-color: rgba(15, 23, 42, 0.08) !important;
        box-shadow: 0 16px 36px rgba(15, 23, 42, 0.06) !important;
      }

      :root[data-olvend-theme="light"] .nav-status {
        background: rgba(15, 23, 42, 0.05) !important;
        border-color: rgba(15, 23, 42, 0.08) !important;
        color: #667085 !important;
      }

      :root[data-olvend-theme="light"] .nav-collapse-toggle {
        color: #18202a !important;
        background: rgba(15, 23, 42, 0.04) !important;
        border-color: rgba(15, 23, 42, 0.08) !important;
      }

      :root[data-olvend-theme="light"] .nav-collapse-toggle:hover {
        background: rgba(15, 23, 42, 0.08) !important;
      }

      :root[data-olvend-theme="light"] .nav a.active,
      :root[data-olvend-theme="light"] .mobile-nav-panel a.active {
        background: rgba(15, 23, 42, 0.06) !important;
        border-color: rgba(15, 23, 42, 0.12) !important;
      }

      :root[data-olvend-theme="light"] .nav a.active .nav-dot {
        background: #d5101a !important;
        box-shadow: none !important;
      }

      :root[data-olvend-theme="light"] .mobile-nav-icon {
        border-right-color: rgba(24,32,42,0.72) !important;
        border-bottom-color: rgba(24,32,42,0.72) !important;
      }

      :root[data-olvend-theme="light"] .nav-dot {
        background: rgba(24,32,42,0.2) !important;
      }

      :root[data-olvend-theme="light"] .tool-btn,
      :root[data-olvend-theme="light"] .back-btn,
      :root[data-olvend-theme="light"] .btn.secondary,
      :root[data-olvend-theme="light"] .btn.ghost,
      :root[data-olvend-theme="light"] .secondary-btn,
      :root[data-olvend-theme="light"] .ghost-btn,
      :root[data-olvend-theme="light"] .content-link,
      :root[data-olvend-theme="light"] .dropdown-item,
      :root[data-olvend-theme="light"] .dashboard-dropdown-btn {
        color: #18202a !important;
        background: rgba(15, 23, 42, 0.04) !important;
        border-color: rgba(15, 23, 42, 0.08) !important;
      }

      :root[data-olvend-theme="light"] .tool-btn:hover,
      :root[data-olvend-theme="light"] .back-btn:hover,
      :root[data-olvend-theme="light"] .btn.secondary:hover,
      :root[data-olvend-theme="light"] .btn.ghost:hover,
      :root[data-olvend-theme="light"] .secondary-btn:hover,
      :root[data-olvend-theme="light"] .ghost-btn:hover,
      :root[data-olvend-theme="light"] .dropdown-item:hover {
        background: rgba(15, 23, 42, 0.08) !important;
      }

      :root[data-olvend-theme="light"] .dashboard-dropdown-menu,
      :root[data-olvend-theme="light"] .popover,
      :root[data-olvend-theme="light"] .menu,
      :root[data-olvend-theme="light"] .dropdown-menu {
        background: rgba(255,255,255,0.98) !important;
        border-color: rgba(15,23,42,0.08) !important;
        box-shadow: 0 24px 60px rgba(15,23,42,0.12) !important;
      }

      :root[data-olvend-theme="light"] input,
      :root[data-olvend-theme="light"] select,
      :root[data-olvend-theme="light"] textarea {
        color: #18202a !important;
        background: rgba(255,255,255,0.96) !important;
        border-color: rgba(15,23,42,0.12) !important;
      }

      :root[data-olvend-theme="light"] input::placeholder,
      :root[data-olvend-theme="light"] textarea::placeholder {
        color: #98a2b3 !important;
      }

      :root[data-olvend-theme="light"] table,
      :root[data-olvend-theme="light"] thead,
      :root[data-olvend-theme="light"] tbody,
      :root[data-olvend-theme="light"] tr {
        border-color: rgba(15,23,42,0.08) !important;
      }

      :root[data-olvend-theme="light"] .widget-header,
      :root[data-olvend-theme="light"] .panel-header,
      :root[data-olvend-theme="light"] .table-header,
      :root[data-olvend-theme="light"] .content-top,
      :root[data-olvend-theme="light"] .modal-head {
        border-color: rgba(15,23,42,0.08) !important;
      }

      :root[data-olvend-theme="light"] .status-chip,
      :root[data-olvend-theme="light"] .mini-badge,
      :root[data-olvend-theme="light"] .pill,
      :root[data-olvend-theme="light"] .badge {
        color: #344054 !important;
      }

      :root[data-olvend-theme="light"] .logout-btn,
      :root[data-olvend-theme="light"] .btn.primary,
      :root[data-olvend-theme="light"] .release-btn.primary,
      :root[data-olvend-theme="light"] .primary-btn,
      :root[data-olvend-theme="light"] .tool-btn.accent {
        color: #ffffff !important;
      }

      :root[data-olvend-theme="light"] .modal-backdrop,
      :root[data-olvend-theme="light"] .overlay {
        background: rgba(15, 23, 42, 0.32) !important;
      }

      :root[data-olvend-theme="light"] .mobile-page,
      :root[data-olvend-theme="light"] .mobile-focus-body,
      :root[data-olvend-theme="light"] .mobile-section-stack,
      :root[data-olvend-theme="light"] .widget-grid {
        color: #18202a !important;
      }

      :root[data-olvend-theme="light"] .mobile-shift-hub,
      :root[data-olvend-theme="light"] .mobile-focus-panel,
      :root[data-olvend-theme="light"] .mobile-shift-tile,
      :root[data-olvend-theme="light"] .mobile-section-card,
      :root[data-olvend-theme="light"] .hero-card,
      :root[data-olvend-theme="light"] .action-card,
      :root[data-olvend-theme="light"] .instruction-card,
      :root[data-olvend-theme="light"] .log-card,
      :root[data-olvend-theme="light"] .service-inline-card,
      :root[data-olvend-theme="light"] .service-request-card,
      :root[data-olvend-theme="light"] .route-stop-card,
      :root[data-olvend-theme="light"] .instruction-compact-group,
      :root[data-olvend-theme="light"] .instruction-compact-item,
      :root[data-olvend-theme="light"] .vehicle-log-card,
      :root[data-olvend-theme="light"] .profile-section-card,
      :root[data-olvend-theme="light"] .profile-card,
      :root[data-olvend-theme="light"] .availability-card,
      :root[data-olvend-theme="light"] .profile-plan-card,
      :root[data-olvend-theme="light"] .mobile-bottom-nav-inner,
      :root[data-olvend-theme="light"] .mobile-bottom-link,
      :root[data-olvend-theme="light"] .mobile-tabbar,
      :root[data-olvend-theme="light"] .mobile-tab,
      :root[data-olvend-theme="light"] .start-review-card,
      :root[data-olvend-theme="light"] .mobile-inline-warning {
        background: rgba(255,255,255,0.94) !important;
        border-color: rgba(15,23,42,0.08) !important;
        box-shadow: 0 14px 34px rgba(15, 23, 42, 0.08) !important;
      }

      :root[data-olvend-theme="light"] .mobile-shift-tile.active,
      :root[data-olvend-theme="light"] .mobile-bottom-link.active,
      :root[data-olvend-theme="light"] .mobile-tab.active,
      :root[data-olvend-theme="light"] .hero-card.primary,
      :root[data-olvend-theme="light"] .content-card.active {
        background: rgba(15, 23, 42, 0.06) !important;
        border-color: rgba(15, 23, 42, 0.12) !important;
      }

      :root[data-olvend-theme="light"] .mobile-shift-tile.done {
        background: rgba(46, 204, 113, 0.08) !important;
        border-color: rgba(46, 204, 113, 0.2) !important;
      }

      :root[data-olvend-theme="light"] .mobile-shift-tile.locked {
        background: rgba(15, 23, 42, 0.04) !important;
        border-color: rgba(15, 23, 42, 0.08) !important;
      }

      :root[data-olvend-theme="light"] .mobile-shift-tile-icon,
      :root[data-olvend-theme="light"] .mobile-bottom-link-icon,
      :root[data-olvend-theme="light"] .widget-action {
        background: rgba(15, 23, 42, 0.06) !important;
        color: #18202a !important;
        border-color: rgba(15, 23, 42, 0.08) !important;
      }

      :root[data-olvend-theme="light"] .mobile-focus-kicker,
      :root[data-olvend-theme="light"] .mobile-section-label,
      :root[data-olvend-theme="light"] .mobile-count-chip small,
      :root[data-olvend-theme="light"] .mobile-bottom-link-note,
      :root[data-olvend-theme="light"] .instruction-compact-note,
      :root[data-olvend-theme="light"] .status-copy,
      :root[data-olvend-theme="light"] .widget-title-wrap p {
        color: #667085 !important;
      }

      :root[data-olvend-theme="light"] .mobile-shift-tile-title,
      :root[data-olvend-theme="light"] .mobile-shift-tile-meta,
      :root[data-olvend-theme="light"] .mobile-shift-tile-note,
      :root[data-olvend-theme="light"] .mobile-focus-title,
      :root[data-olvend-theme="light"] .mobile-focus-body,
      :root[data-olvend-theme="light"] .mobile-back-btn,
      :root[data-olvend-theme="light"] .mobile-section-value,
      :root[data-olvend-theme="light"] .mobile-section-title,
      :root[data-olvend-theme="light"] .mobile-section-text,
      :root[data-olvend-theme="light"] .mobile-count-chip,
      :root[data-olvend-theme="light"] .hero-card h3,
      :root[data-olvend-theme="light"] .hero-card p,
      :root[data-olvend-theme="light"] .action-card h3,
      :root[data-olvend-theme="light"] .action-card p,
      :root[data-olvend-theme="light"] .instruction-card,
      :root[data-olvend-theme="light"] .service-inline-card,
      :root[data-olvend-theme="light"] .service-request-card,
      :root[data-olvend-theme="light"] .route-stop-card,
      :root[data-olvend-theme="light"] .profile-section-card h3,
      :root[data-olvend-theme="light"] .profile-section-card p,
      :root[data-olvend-theme="light"] .profile-card h3,
      :root[data-olvend-theme="light"] .profile-card p,
      :root[data-olvend-theme="light"] .availability-card,
      :root[data-olvend-theme="light"] .profile-plan-card,
      :root[data-olvend-theme="light"] .mobile-bottom-link-label,
      :root[data-olvend-theme="light"] .mobile-tab,
      :root[data-olvend-theme="light"] .widget-action,
      :root[data-olvend-theme="light"] .widget-header h2,
      :root[data-olvend-theme="light"] .widget-header h3 {
        color: #18202a !important;
      }

      :root[data-olvend-theme="light"] .mobile-back-btn,
      :root[data-olvend-theme="light"] .mobile-count-chip,
      :root[data-olvend-theme="light"] .instruction-compact-summary,
      :root[data-olvend-theme="light"] .widget-action {
        background: rgba(15, 23, 42, 0.04) !important;
        border-color: rgba(15, 23, 42, 0.08) !important;
      }
    `;

    document.head.appendChild(style);
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

  function setupSidebarCollapsing(root) {
    root.querySelectorAll("[data-collapse-nav]").forEach((button) => {
      button.addEventListener("click", () => {
        const key = button.dataset.collapseNav;
        const shell = button.closest(".nav-item-shell");
        if (!key || !shell) return;
        const nextCollapsed = !shell.classList.contains("collapsed");
        shell.classList.toggle("collapsed", nextCollapsed);
        button.setAttribute("aria-expanded", nextCollapsed ? "false" : "true");
        button.setAttribute("title", nextCollapsed ? "Rozbalit" : "Sbalit");
        setNavGroupCollapsed(key, nextCollapsed);
      });
    });
  }

  initTheme();

  const sidebar = document.querySelector(".sidebar");
  if (sidebar) {
    injectSidebarReorderStyles();
    sidebar.innerHTML = renderSidebar();
    setupSidebarCollapsing(sidebar);
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
