(function () {
  const currentPath = window.location.pathname.split("/").pop() || "dashboard.html";

  const pageMeta = {
    "dashboard.html": {
      currentLabel: "Dashboard",
      activeKey: "dashboard",
      versionLabel: "Verze aplikace",
      versionValue: "OLVEND v1.0",
      versionNote: "Sdílený dashboard pro provoz, HR přehled a další moduly systému."
    },
    "attendance.html": {
      currentLabel: "Moje směna",
      activeKey: "shift",
      versionLabel: "Verze modulu",
      versionValue: "Moje směna 1.1",
      versionNote: "Mobil-first vstup do dne s pokyny, rychlým startem směny, pauzou a ukončením bez zbytečného přetížení."
    },
    "warehouses.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Verze aplikace",
      versionValue: "OLVEND v1.0",
      versionNote: "Správa skladů jako systémového základu pro provoz, směny a další moduly."
    },
    "hr.html": {
      currentLabel: "HR",
      activeKey: "hr",
      versionLabel: "Verze modulu",
      versionValue: "HR 1.0",
      versionNote: "První HR vrstva nad docházkou: přehledy, výjimky, exporty a kontrolní pohled na směny."
    },
    "hr-planning.html": {
      currentLabel: "Plán směn",
      activeKey: "hr",
      versionLabel: "Verze modulu",
      versionValue: "HR Planning 1.1",
      versionNote: "Samostatný planner směn s plnou šířkou pro rozpis, úvazky a publikaci plánu."
    },
    "reporty.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Verze modulu",
      versionValue: "Reporty 1.1",
      versionNote: "Vstupní vrstva pro výstupy nad docházkou, plánem směn a navazujícími manažerskými přehledy."
    },
    "report-attendance.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Verze modulu",
      versionValue: "Reporty 1.1",
      versionNote: "Samostatný docházkový report s filtry, souhrny a exporty pro vedení, HR a další kontrolní práci."
    },
    "settings.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Verze aplikace",
      versionValue: "OLVEND v1.0",
      versionNote: "Administrace systémových základů, firemních údajů a personálních modulů."
    },
    "employees.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Verze aplikace",
      versionValue: "OLVEND v1.0",
      versionNote: "Správa zaměstnanců, rolí, skladů a docházkových vazeb."
    },
    "vehicles.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Verze aplikace",
      versionValue: "OLVEND v1.0",
      versionNote: "Správa vozidel jako provozního základu pro docházku, trasy a další moduly."
    },
    "company.html": {
      currentLabel: "Nastavení",
      activeKey: "settings",
      versionLabel: "Verze aplikace",
      versionValue: "OLVEND v1.0",
      versionNote: "Základní firemní karta, kontakty a provozní údaje připravené pro další rozvoj systému."
    }
  };

  const meta = pageMeta[currentPath] || pageMeta["dashboard.html"];

  const navItems = [
    { key: "dashboard", href: "dashboard.html", label: "Dashboard" },
    { key: "shift", href: "attendance.html", label: "Moje směna" },
    { key: "service", href: "#", label: "Servis", soon: true },
    { key: "operations", href: "#", label: "Provoz", soon: true },
    { key: "hr", href: "hr.html", label: "HR" },
    { key: "reporty", href: "reporty.html", label: "Reporty" },
    { key: "settings", href: "settings.html", label: "Nastavení" }
  ];

  function renderDesktopNav() {
    return navItems.map((item) => {
      const activeClass = item.key === meta.activeKey ? "active" : "";
      const status = item.soon ? '<span class="nav-status">Brzy</span>' : "";
      return `
        <a href="${item.href}" class="${activeClass}">
          <span class="nav-dot"></span>
          <span>${item.label}</span>
          ${status}
        </a>
      `;
    }).join("");
  }

  function renderMobileLinks() {
    return navItems
      .filter((item) => !item.soon || ["dashboard", "shift", "hr", "settings"].includes(item.key))
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
        <nav class="nav">
          ${renderDesktopNav()}
        </nav>
      </div>

      <div class="sidebar-bottom">
        <div class="version-box">
          <div class="version-label">${meta.versionLabel}</div>
          <div class="version-value">${meta.versionValue}</div>
          <div class="version-note">${meta.versionNote}</div>
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

  const sidebar = document.querySelector(".sidebar");
  if (sidebar) {
    sidebar.innerHTML = renderSidebar();
  }

  const mobileShell = document.querySelector(".mobile-nav-shell");
  if (mobileShell) {
    mobileShell.innerHTML = renderMobileShell();
  }

  const mobileGlobalNav = document.querySelector(".mobile-global-nav");
  if (mobileGlobalNav) {
    mobileGlobalNav.innerHTML = renderMobileGlobalNav();
  }
})();
