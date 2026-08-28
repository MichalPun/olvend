(function () {
  const currentPath = window.location.pathname.split("/").pop() || "dashboard.html";
  const currentPathWithQuery = `${currentPath}${window.location.search || ""}`;
  const RELEASE_NOTES_KEY = "olvendSeenReleaseNotesV18";
  const APP_THEME_KEY = "olvendThemePreference";
  const NAV_COLLAPSE_KEY = "olvendCollapsedNavGroups";
  const COMPACT_NAV_INIT_KEY = "olvendCompactSidebarV2";
  const APP_VERSION = "OLVEND 1.8";
  const MIN_RELEASE_ANNOUNCEMENT = "1.8";
  const RELEASE_NOTES = {
    "1.8": {
      title: "OLVEND 1.8 je připraven",
      subtitle: "Trasy, inventury a sklad teď navazují v jednom pracovním toku.",
      items: [
        "Mobilní trasy vedou operátora od převzetí přes práci u automatu až po uzavření návštěvy.",
        "Cílené inventury vybírají rizikové položky a zachovávají vysvětlení i rozhodnutí nadřízeného.",
        "Nový mobilní Sklad sjednocuje převzetí, nakládku, vrácení, odpisy a provozní požadavky.",
        "Dodávky partnerům přecházejí ze skladu do fronty pro fakturaci podle skutečně vydaného množství.",
        "Průběžné ukládání a opravené přepočty zvyšují spolehlivost při slabém připojení."
      ]
    },
    "1.7": {
      title: "Nová verze 1.7",
      subtitle: "Skladové hospodářství dostává automatickou nakládku, balení v kartách zásob a paměť odložených potřeb.",
      items: [
        "Automatická nakládka navrhuje celé balení podle historie konkrétního vozidla, aktuálního stavu na autě a zvoleného typu jízdy.",
        "Systém si pamatuje položky, které se minule nenaložily kvůli nízkému využití balení, a přičte je do dalšího návrhu.",
        "Karty zásob mají balení a přepočty, takže sklad zůstává v kusech, gramech nebo mililitrech, ale převodka umí karton, balení, kg i l.",
        "Přibyly cílené inventury rizikových zůstatků na vozidle, když se zboží dlouho nehýbe a reálně už na autě být nemusí.",
        "Operátorka už běžně nemusí psát objednávku nakládky. Skladník může návrh připravit dopředu a operátorka řeší hlavně výjimky.",
        "Bagety zůstávají v opatrnějším režimu: systém je umí navrhovat, ale kvůli čerstvosti a lokálním rozdílům doporučujeme ponechat možnost ruční korekce před nakládkou."
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
      currentLabel: "Lidé a směny",
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
    "route-dispatch.html": {
      currentLabel: "Denní plán tras",
      activeKey: "route-dispatch",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "controlling.html": {
      currentLabel: "Kontrolní trasy",
      activeKey: "controlling",
      versionLabel: "Návrh verze",
      versionValue: APP_VERSION,
      versionNote: "PC část kontrolingu"
    },
    "operational-requests.html": {
      currentLabel: "Požadavky a výdeje",
      activeKey: "operational-requests",
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
    "telemetry.html": {
      currentLabel: "Telemetrie",
      activeKey: "telemetry",
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
    "issued-invoices.html": {
      currentLabel: "Vystavené faktury",
      activeKey: "sales-invoices",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "budget.html": {
      currentLabel: "Rozpočet",
      activeKey: "budget",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "cash-collection.html": {
      currentLabel: "Svoz hotovosti",
      activeKey: "cash-collection",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "suppliers.html": {
      currentLabel: "Kontakty",
      activeKey: "suppliers",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "hr-planning.html": {
      currentLabel: "Plán směn",
      activeKey: "hr-planning",
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
    "payroll.html": {
      currentLabel: "Mzdy",
      activeKey: "payroll",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "meeting-calendar.html": {
      currentLabel: "Kalendář a schůzky",
      activeKey: "meeting-calendar",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "mail.html": {
      currentLabel: "E-mail",
      activeKey: "mail",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "mail-settings.html": {
      currentLabel: "Nastavení e-mailu",
      activeKey: "mail-settings",
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
    "report-routes-daily.html": {
      currentLabel: "Denní vyhodnocení tras",
      activeKey: "report-routes-daily",
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
    "report-route-kilometers.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "report-monthly-review.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "report-invoice-comparison.html": {
      currentLabel: "Reporty",
      activeKey: "reporty",
      versionLabel: "Aktuální verze",
      versionValue: APP_VERSION,
      versionNote: ""
    },
    "report-telemetry.html": {
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
      currentLabel: "Zaměstnanci",
      activeKey: "employees",
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
        { key: "home", href: "dashboard.html", label: "Přehled" },
        { key: "shift", href: "mobile.html", label: "Moje směna" }
      ]
    },
    {
      key: "operations",
      title: "Provoz",
      items: [
        { key: "suppliers", href: "suppliers.html", label: "Klienti a kontakty" },
        {
          key: "machines-management",
          href: "machines.html",
          label: "Stroje",
          children: [
            { key: "machines", href: "machines.html", label: "Přehled strojů" },
            { key: "telemetry", href: "telemetry.html", label: "Telemetrie" }
          ]
        },
        {
          key: "logistics-management",
          href: "routes.html",
          label: "Trasy",
          children: [
            { key: "routes", href: "routes.html", label: "Přehled tras" },
            { key: "route-dispatch", href: "route-dispatch.html", label: "Naplánovat tým" },
            { key: "controlling", href: "controlling.html", label: "Kontrolní trasy" },
            { key: "operations", href: "operations.html", label: "Lokality" },
            { key: "fleet", href: "vehicles.html", label: "Vozový park" }
          ]
        },
        {
          key: "stock-management",
          href: "inventory.html",
          label: "Sklad",
          children: [
            { key: "inventory", href: "inventory.html", label: "Zásoby" },
            { key: "operational-requests", href: "inventory.html?tab=movements&warehouseView=requests", label: "Požadavky a výdeje" },
            { key: "purchases-recurring", href: "purchases.html?view=recurring", label: "Stálé objednávky" }
          ]
        },
        {
          key: "technical-management",
          href: "technical-jobs.html",
          label: "Technické zásahy",
          children: [
            { key: "technical-jobs", href: "technical-jobs.html", label: "Přehled zásahů" },
            { key: "service-requests", href: "service-requests.html", label: "Servisní požadavky" },
            { key: "qr-labels", href: "machine-qr-print.html", label: "QR štítky" }
          ]
        }
      ]
    },
    {
      key: "management",
      title: "Řízení",
      items: [
        {
          key: "finance-management",
          href: "issued-invoices.html",
          label: "Finance",
          children: [
            { key: "sales-invoices", href: "issued-invoices.html", label: "Vystavené faktury" },
            { key: "purchases-overview", href: "purchases.html?view=received", label: "Přijaté doklady" },
            { key: "cash-collection", href: "cash-collection.html", label: "Svoz hotovosti" },
            { key: "budget", href: "budget.html", label: "Rozpočet" }
          ]
        },
        {
          key: "management-work",
          href: "tasks.html",
          label: "Úkoly a schvalování",
          children: [
            { key: "approvals", href: "approval-center.html", label: "Schvalování" },
            { key: "tasks", href: "tasks.html", label: "Manažerský blok" }
          ]
        },
        { key: "mail", href: "mail.html", label: "E-mail" },
        {
          key: "management-people",
          href: "hr.html",
          label: "Lidé",
          children: [
            { key: "hr", href: "hr.html", label: "HR přehled" },
            { key: "hr-planning", href: "hr-planning.html", label: "Plán směn" },
            { key: "meeting-calendar", href: "meeting-calendar.html", label: "Kalendář a schůzky" },
            { key: "employees", href: "employees.html", label: "Zaměstnanci" }
          ]
        },
        {
          key: "management-reports",
          href: "reporty.html",
          label: "Reporty",
          children: [
            { key: "reporty", href: "reporty.html", label: "Přehled reportů" },
            { key: "payroll", href: "payroll.html", label: "Mzdy" },
            { key: "report-attendance", href: "report-attendance.html", label: "Docházka" },
            { key: "report-shift-overview", href: "report-shift-overview.html", label: "Směny" },
            { key: "report-routes-daily", href: "report-routes-daily.html", label: "Denní trasy" },
            { key: "report-route-kilometers", href: "report-route-kilometers.html", label: "Kilometry tras" },
            { key: "report-vehicles", href: "report-vehicles.html", label: "Vozidla" },
            { key: "report-monthly-review", href: "report-monthly-review.html", label: "Měsíční uzávěrka" },
            { key: "report-invoice-comparison", href: "report-invoice-comparison.html", label: "Srovnání fakturace" },
            { key: "report-telemetry", href: "report-telemetry.html", label: "Telemetrické reporty" }
          ]
        },
        {
          key: "management-admin",
          href: "settings.html",
          label: "Nastavení",
          children: [
            { key: "settings", href: "settings.html", label: "Nastavení systému" },
            { key: "company", href: "company.html", label: "Firma" },
            { key: "mail-settings", href: "mail-settings.html", label: "Nastavení e-mailu" }
          ]
        }
      ]
    }
  ];

  function flattenNavItems(items) {
    return items.flatMap((item) => [item, ...(item.children ? flattenNavItems(item.children) : [])]);
  }

  const navItems = navGroups.flatMap((group) => flattenNavItems(group.items));

  function updateThemeMeta() {
    const metaTheme = document.querySelector('meta[name="theme-color"]');
    if (metaTheme) {
      metaTheme.setAttribute("content", "#f4f5f7");
    }
  }

  function initTheme() {
    localStorage.removeItem(APP_THEME_KEY);
    document.documentElement.dataset.olvendTheme = "light";
    document.documentElement.dataset.olvendThemePreference = "light";
    document.documentElement.style.colorScheme = "light";
    updateThemeMeta();

    window.OLVEND_THEME = {
      getPreference: () => "light",
      getResolvedTheme: () => "light",
      setPreference: () => ({ preference: "light", theme: "light" })
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

  function initializeCompactSidebar() {
    if (localStorage.getItem(COMPACT_NAV_INIT_KEY) === "1") return;
    const parentKeys = navGroups
      .flatMap((group) => group.items)
      .filter((item) => Array.isArray(item.children) && item.children.length)
      .map((item) => item.key);
    localStorage.setItem(NAV_COLLAPSE_KEY, JSON.stringify(parentKeys));
    localStorage.setItem(COMPACT_NAV_INIT_KEY, "1");
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

  const NAV_ICON_PATHS = {
    home: '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    contacts: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
    machine: '<rect x="5" y="2" width="14" height="20" rx="2"/><path d="M8 6h8M8 10h8M9 18h6M12 14v4"/>',
    routes: '<circle cx="6" cy="19" r="2"/><circle cx="18" cy="5" r="2"/><path d="M8 19h3a4 4 0 0 0 4-4V9a4 4 0 0 1 3-4"/>',
    stock: '<path d="m21 8-9-5-9 5 9 5 9-5Z"/><path d="m3 12 9 5 9-5M3 16l9 5 9-5"/>',
    tools: '<path d="M14.7 6.3a4 4 0 0 0-5-5L7 4l3 3 2.7-.7Z"/><path d="m10 7-8 8a2.1 2.1 0 0 0 3 3l8-8"/><path d="m14 14 6 6"/>',
    finance: '<path d="M6 2h9l4 4v16H6z"/><path d="M14 2v5h5M9 12h6M9 16h6"/>',
    tasks: '<rect x="3" y="4" width="18" height="17" rx="2"/><path d="m8 10 2 2 4-4M8 16h8"/>',
    people: '<circle cx="12" cy="7" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    reports: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
    calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 10h18"/><path d="m8 15 2 2 5-5"/>',
    payroll: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 8h8M8 12h3M8 16h3M15 12v5M13 14h4"/>',
    vehicle: '<path d="M5 17h14l-1-7a2 2 0 0 0-2-2H8a2 2 0 0 0-2 2l-1 7Z"/><path d="M3 17h18M7 17v3M17 17v3M8 12h8"/>',
    invoice: '<path d="M6 2h9l4 4v16H6z"/><path d="M14 2v5h5M9 12h6M9 16h4"/><path d="m15 18 1.5 1.5L20 16"/>',
    telemetry: '<path d="M4 19V5M4 19h16"/><path d="m7 15 3-4 3 2 5-7"/><circle cx="18" cy="6" r="1"/>',
    mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>',
    settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.83 2.83-.06-.06A1.7 1.7 0 0 0 15 19.4a1.7 1.7 0 0 0-1 .6 1.7 1.7 0 0 0-.4 1.1V21h-4v-.09A1.7 1.7 0 0 0 8.6 19.4a1.7 1.7 0 0 0-1.88.34l-.06.06-2.83-2.83.06-.06A1.7 1.7 0 0 0 4.6 15a1.7 1.7 0 0 0-.6-1 1.7 1.7 0 0 0-1.1-.4H3v-4h.09A1.7 1.7 0 0 0 4.6 8.6a1.7 1.7 0 0 0-.34-1.88l-.06-.06 2.83-2.83.06.06A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-.6 1.7 1.7 0 0 0 .4-1.1V3h4v.09A1.7 1.7 0 0 0 15.4 4.6a1.7 1.7 0 0 0 1.88-.34l.06-.06 2.83 2.83-.06.06A1.7 1.7 0 0 0 19.4 9c.2.37.53.69.9.9.34.2.73.3 1.1.3H21v4h-.09a1.7 1.7 0 0 0-1.51.8Z"/>',
    dot: '<circle cx="12" cy="12" r="3"/>'
  };

  const NAV_ICON_ALIASES = {
    shift: 'clock', suppliers: 'contacts', 'machines-management': 'machine', machines: 'machine', telemetry: 'reports',
    'logistics-management': 'routes', routes: 'routes', controlling: 'tasks', operations: 'routes', fleet: 'routes',
    'stock-management': 'stock', inventory: 'stock', 'operational-requests': 'stock', 'purchases-recurring': 'stock',
    'technical-management': 'tools', 'technical-jobs': 'tools', 'service-requests': 'tools', 'qr-labels': 'machine',
    'finance-management': 'finance', 'sales-invoices': 'finance', 'purchases-overview': 'finance', 'cash-collection': 'finance', budget: 'reports',
    'management-work': 'tasks', approvals: 'tasks', tasks: 'tasks', mail: 'mail',
    'management-people': 'people', hr: 'people', 'hr-planning': 'people', 'meeting-calendar': 'calendar', employees: 'people',
    'management-reports': 'reports', reporty: 'reports', payroll: 'payroll',
    'report-attendance': 'calendar', 'report-shift-overview': 'clock', 'report-routes-daily': 'routes',
    'report-vehicles': 'vehicle', 'report-monthly-review': 'finance', 'report-invoice-comparison': 'invoice',
    'report-telemetry': 'telemetry', 'management-admin': 'settings', settings: 'settings', company: 'settings', 'mail-settings': 'mail'
  };

  function getNavIcon(item) {
    const iconKey = NAV_ICON_ALIASES[item.key] || item.key;
    const paths = NAV_ICON_PATHS[iconKey] || NAV_ICON_PATHS.dot;
    return `<span class="nav-icon" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${paths}</svg></span>`;
  }

  function renderNavLinks(items) {
    return items.map((item) => {
      const isActive = isItemActive(item);
      const activeClass = isActive ? "active" : "";
      const status = item.soon ? '<span class="nav-status">Brzy</span>' : "";
      const unread = item.key === "mail" ? '<span class="nav-unread-badge" data-mail-unread hidden aria-label="0 nepřečtených e-mailů"></span>' : "";
      const hasChildren = Array.isArray(item.children) && item.children.length;
      const collapsed = hasChildren && !isActive;
      const expanded = hasChildren && !collapsed;
      const childLinks = Array.isArray(item.children) && item.children.length
        ? `<div class="nav-subitems" id="nav-children-${item.key}">${renderNavLinks(item.children)}</div>`
        : "";
      const itemLabel = `
        ${getNavIcon(item)}
        <span>${item.label}</span>
        ${unread}
        ${status}
      `;
      return `
        <div class="nav-item-shell ${hasChildren ? "has-children" : ""} ${collapsed ? "collapsed" : ""}">
          <div class="nav-link-row">
            ${hasChildren
              ? `<button class="nav-parent-button ${activeClass}" type="button" data-collapse-nav="${item.key}" aria-expanded="${expanded ? "true" : "false"}" aria-controls="nav-children-${item.key}" title="${expanded ? "Sbalit" : "Rozbalit"}">${itemLabel}<span class="nav-chevron"></span></button>`
              : `<a href="${item.href}" class="${activeClass}" data-nav-key="${item.key}">${itemLabel}</a>`}
          </div>
          ${childLinks}
        </div>
      `;
    }).join("");
  }

  function renderDesktopNav() {
    return `<nav class="nav">${navGroups.map((group) => renderNavLinks(group.items.filter((item) => item.key !== "shift"))).join("")}</nav>`;
  }

  function renderMobileLinks() {
    return navGroups.map((group) => {
      const flattenedItems = flattenNavItems(group.items);
      const managementMobileKeys = ["approvals", "tasks", "hr", "hr-planning", "employees", "reporty", "settings"];
      const filteredItems = group.key === "management"
        ? flattenedItems.filter((item) => !item.soon && managementMobileKeys.includes(item.key))
        : flattenedItems.filter((item) => !item.soon || ["home", "shift", "machines", "inventory", "purchases", "sales-invoices", "budget", "suppliers", "warehouses", "service", "fleet", "hr", "settings"].includes(item.key));
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
        <div class="brand-mark">O</div>
        <div><div class="brand-logo">OL<span>VEND</span></div><div class="brand-system">Provozní systém</div></div>
      </div>

      <div class="nav-group global-nav-group">
        ${renderDesktopNav()}
      </div>

      <div class="sidebar-bottom">
        <div class="version-box">
          <div class="version-label">${meta.versionLabel}</div>
          <div class="version-value">${meta.versionValue}</div>
          ${meta.versionNote ? `<div class="version-note">${meta.versionNote}</div>` : ""}
          <button class="release-btn" type="button" id="openReleaseNotesButton" style="width:100%;margin-top:8px;padding:8px 10px;color:#fff;background:rgba(255,255,255,.06)">Novinky 1.8</button>
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
        padding: 16px 12px;
        border-right: 1px solid rgba(255,255,255,0.08);
        background: linear-gradient(180deg, rgba(20,22,28,.98), rgba(12,13,17,.98));
        backdrop-filter: blur(14px);
        overflow-y: auto;
      }

      .layout {
        grid-template-columns: 224px minmax(0, 1fr) !important;
      }

      .brand {
        display:flex;
        align-items:center;
        gap:10px;
        padding: 4px 7px 16px;
        margin-bottom:6px;
        border-bottom:1px solid rgba(255,255,255,.07);
      }

      .brand-mark {
        width:34px;height:34px;border-radius:9px;display:grid;place-items:center;
        background:#d5101a;color:#fff;font-size:17px;font-weight:900;
        box-shadow:0 8px 22px rgba(213,16,26,.28);
      }

      .brand-logo {
        font-size: 20px;
        font-weight: 800;
        letter-spacing: -0.05em;
        line-height: 1;
        margin-bottom: 0;
        color: #fff;
      }

      .brand-logo span {
        color: #d5101a;
      }

      .brand-system { margin-top:3px;color:#7f8794;font-size:9px;font-weight:800;letter-spacing:.1em;text-transform:uppercase; }

      .brand-subtitle {
        color: #a5a8b2;
        font-size: 12px;
        line-height: 1.42;
      }

      .global-nav-group,
      .nav-group {
        margin-bottom: 12px;
      }

      .global-nav-title,
      .nav-title {
        margin: 0 0 7px;
        color: #a5a8b2;
        font-size: 11px;
        font-weight: 800;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        padding: 0 8px;
      }

      .nav {
        display: grid;
        gap: 4px;
      }

      .nav-item-shell {
        display: grid;
        gap: 3px;
      }

      .nav-link-row {
        display: block;
      }

      .nav a,
      .nav-parent-button {
        width: 100%;
        display: flex;
        align-items: center;
        gap: 8px;
        min-height:40px;
        padding: 6px 8px;
        border-radius: 8px;
        text-decoration: none;
        color: #fff;
        font-size: 12px;
        font-weight: 700;
        transition: 0.2s ease;
        border: 1px solid transparent;
        background: transparent;
        cursor: pointer;
        text-align: left;
        font-family: inherit;
        line-height: 1.18;
      }

      .nav a:hover,
      .nav-parent-button:hover {
        background: rgba(255,255,255,0.055);
      }

      .nav a.active,
      .nav-parent-button.active {
        background: linear-gradient(90deg, rgba(213,16,26,.18), rgba(213,16,26,.07));
        border-color: rgba(213,16,26,0.3);
        box-shadow:inset 3px 0 0 #d5101a;
      }

      .nav-icon {
        width:28px;height:28px;display:grid;place-items:center;flex:0 0 28px;
        border-radius:7px;color:#8d95a3;background:rgba(255,255,255,.035);
        transition:background .2s ease,color .2s ease,transform .2s ease;
      }

      .nav-icon svg { width:16px;height:16px;display:block; }
      .nav a:hover .nav-icon,.nav-parent-button:hover .nav-icon { color:#fff;transform:translateY(-1px); }
      .nav a.active .nav-icon,.nav-parent-button.active .nav-icon { color:#fff;background:#d5101a;box-shadow:0 6px 14px rgba(213,16,26,.28); }

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

      .nav-unread-badge {
        margin-left: auto;
        min-width: 20px;
        height: 20px;
        padding: 0 6px;
        border-radius: 999px;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        background: #d5101a;
        color: #fff;
        font-size: 10px;
        font-weight: 900;
        line-height: 1;
        box-shadow: 0 4px 10px rgba(213,16,26,.28);
      }

      .nav-unread-badge[hidden] { display: none; }

      .nav-chevron {
        width: 7px;
        height: 7px;
        border-right: 2px solid currentColor;
        border-bottom: 2px solid currentColor;
        transform: rotate(45deg);
        margin: -3px 2px 0 auto;
        opacity: 0.72;
        transition: transform 0.2s ease, margin 0.2s ease;
        flex: 0 0 7px;
      }

      .nav-item-shell.collapsed .nav-chevron {
        transform: rotate(-45deg);
        margin-top: 0;
        margin-left: -2px;
      }

      .nav-subitems {
        display: grid;
        gap: 3px;
        margin: 0 0 5px 20px;
        padding-left: 12px;
        border-left: 1px solid rgba(255,255,255,0.08);
        max-height: 520px;
        opacity: 1;
        overflow: hidden;
        transition: max-height 0.22s ease, opacity 0.18s ease, margin 0.22s ease;
      }

      .nav-item-shell.collapsed .nav-subitems {
        max-height: 0;
        opacity: 0;
        margin-top: 0;
        margin-bottom: 0;
      }

      .nav-subitems a {
        min-height:34px;padding: 5px 8px;
        border-radius: 7px;
        font-size: 11px;
        font-weight: 650;
        color: #d7dae0;
      }

      .nav-subitems .nav-icon { width:22px;height:22px;flex-basis:22px;border-radius:6px;background:transparent; }
      .nav-subitems .nav-icon svg { width:13px;height:13px; }
      .nav-subitems a.active { box-shadow:none; }

      .sidebar-bottom {
        margin-top: auto;
        padding: 10px 8px 4px;
      }

      .version-box {
        padding: 10px;
        border-radius: 10px;
        background: rgba(255,255,255,0.04);
        border: 1px solid rgba(255,255,255,0.08);
      }

      .version-label {
        color: #7d818c;
        font-size: 10px;
        text-transform: uppercase;
        letter-spacing: 0.1em;
        margin-bottom: 6px;
      }

      .version-value {
        font-size: 13px;
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

      .release-role-switch { display:grid; grid-template-columns:repeat(3,1fr); gap:4px; margin:14px 22px 0; padding:4px; border-radius:8px; background:rgba(255,255,255,.06); }
      .release-role-switch button { min-height:40px; border:0; border-radius:6px; background:transparent; color:#a5a8b2; font-weight:800; cursor:pointer; }
      .release-role-switch button.active { background:#fff; color:#17191f; }
      .release-role-note { margin:0 0 12px; color:#a5a8b2; font-size:13px; font-weight:700; }
      .release-rule { margin-top:12px; padding:11px 14px; border-left:4px solid #66a9ff; background:rgba(102,169,255,.09); color:#cbd8ea; font-size:13px; line-height:1.5; }

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
        .layout {
          grid-template-columns: 1fr !important;
        }

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
        background: linear-gradient(180deg,#fff,#f7f8fa) !important;
        border-color: rgba(24,32,42,0.08) !important;
        box-shadow: 0 20px 48px rgba(15, 23, 42, 0.08);
      }

      :root[data-olvend-theme="light"] .release-backdrop {
        background: rgba(236, 240, 245, 0.64);
      }

      :root[data-olvend-theme="light"] .brand-logo,
      :root[data-olvend-theme="light"] .nav a,
      :root[data-olvend-theme="light"] .nav-parent-button,
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
      :root[data-olvend-theme="light"] .nav-parent-button:hover,
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

      :root[data-olvend-theme="light"] .nav-parent-button {
        color: #18202a !important;
      }

      :root[data-olvend-theme="light"] .nav a.active,
      :root[data-olvend-theme="light"] .nav-parent-button.active,
      :root[data-olvend-theme="light"] .mobile-nav-panel a.active {
        background: linear-gradient(90deg,rgba(213,16,26,.12),rgba(213,16,26,.035)) !important;
        border-color: rgba(213,16,26,.22) !important;
      }

      :root[data-olvend-theme="light"] .nav-icon { color:#677080;background:rgba(15,23,42,.035); }
      :root[data-olvend-theme="light"] .nav a.active .nav-icon,
      :root[data-olvend-theme="light"] .nav-parent-button.active .nav-icon { color:#fff;background:#d5101a; }

      :root[data-olvend-theme="light"] .mobile-nav-icon {
        border-right-color: rgba(24,32,42,0.72) !important;
        border-bottom-color: rgba(24,32,42,0.72) !important;
      }

      :root[data-olvend-theme="light"] .brand { border-bottom-color:rgba(15,23,42,.08); }

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

      :root[data-olvend-theme="light"] .modal,
      :root[data-olvend-theme="light"] .modal-card,
      :root[data-olvend-theme="light"] .modal-shell,
      :root[data-olvend-theme="light"] .dialog,
      :root[data-olvend-theme="light"] .dialog-card {
        background: #f8fafc !important;
        color: #17212b !important;
        border-color: rgba(15, 23, 42, 0.14) !important;
        box-shadow: 0 28px 80px rgba(15, 23, 42, 0.22) !important;
      }

      :root[data-olvend-theme="light"] .modal-header,
      :root[data-olvend-theme="light"] .modal-footer,
      :root[data-olvend-theme="light"] .modal-head,
      :root[data-olvend-theme="light"] .modal-body,
      :root[data-olvend-theme="light"] .panel-header,
      :root[data-olvend-theme="light"] .table-header {
        border-color: rgba(15, 23, 42, 0.12) !important;
      }

      :root[data-olvend-theme="light"] .modal h1,
      :root[data-olvend-theme="light"] .modal h2,
      :root[data-olvend-theme="light"] .modal h3,
      :root[data-olvend-theme="light"] .modal h4,
      :root[data-olvend-theme="light"] .modal h5,
      :root[data-olvend-theme="light"] .modal strong,
      :root[data-olvend-theme="light"] .modal td,
      :root[data-olvend-theme="light"] .modal th,
      :root[data-olvend-theme="light"] .modal label,
      :root[data-olvend-theme="light"] .modal .summary-box-value,
      :root[data-olvend-theme="light"] .modal .sales-summary-value,
      :root[data-olvend-theme="light"] .modal .detail-sheet-value,
      :root[data-olvend-theme="light"] .modal .detail-list-value,
      :root[data-olvend-theme="light"] .modal .mobile-pick-meta-value {
        color: #17212b !important;
      }

      :root[data-olvend-theme="light"] .modal p,
      :root[data-olvend-theme="light"] .modal .subtext,
      :root[data-olvend-theme="light"] .modal .helper-line,
      :root[data-olvend-theme="light"] .modal .sales-summary-note,
      :root[data-olvend-theme="light"] .modal .summary-box-label,
      :root[data-olvend-theme="light"] .modal .sales-summary-label,
      :root[data-olvend-theme="light"] .modal .field label,
      :root[data-olvend-theme="light"] .modal .mobile-pick-meta-note,
      :root[data-olvend-theme="light"] .modal .mobile-pick-meta-label {
        color: #475467 !important;
      }

      :root[data-olvend-theme="light"] .modal input,
      :root[data-olvend-theme="light"] .modal select,
      :root[data-olvend-theme="light"] .modal textarea {
        background: #ffffff !important;
        border-color: rgba(15, 23, 42, 0.18) !important;
        color: #101828 !important;
        box-shadow: inset 0 1px 0 rgba(15, 23, 42, 0.02) !important;
      }

      :root[data-olvend-theme="light"] .modal input:focus,
      :root[data-olvend-theme="light"] .modal select:focus,
      :root[data-olvend-theme="light"] .modal textarea:focus {
        border-color: rgba(213, 16, 26, 0.55) !important;
        box-shadow: 0 0 0 3px rgba(213, 16, 26, 0.12) !important;
      }

      :root[data-olvend-theme="light"] .modal .summary-box,
      :root[data-olvend-theme="light"] .modal .sales-summary-card,
      :root[data-olvend-theme="light"] .modal .sales-summary-item,
      :root[data-olvend-theme="light"] .modal .transfer-line-row,
      :root[data-olvend-theme="light"] .modal .config-table-row,
      :root[data-olvend-theme="light"] .modal .mobile-pick-request-card,
      :root[data-olvend-theme="light"] .modal .mobile-pick-detail,
      :root[data-olvend-theme="light"] .modal .mobile-pick-add-line,
      :root[data-olvend-theme="light"] .modal .mini-excel-table,
      :root[data-olvend-theme="light"] .modal tr {
        background: #ffffff !important;
        border-color: rgba(15, 23, 42, 0.12) !important;
      }

      :root[data-olvend-theme="light"] .modal th {
        background: #eef2f7 !important;
        color: #344054 !important;
      }

      :root[data-olvend-theme="light"] .modal .badge.good,
      :root[data-olvend-theme="light"] .modal .mobile-pick-source-label,
      :root[data-olvend-theme="light"] .modal .stock-ok,
      :root[data-olvend-theme="light"] .modal .status-ok {
        color: #027a48 !important;
        background: rgba(46, 204, 113, 0.12) !important;
        border-color: rgba(46, 204, 113, 0.34) !important;
      }

      :root[data-olvend-theme="light"] .modal .badge.warn,
      :root[data-olvend-theme="light"] .modal .helper-line.warn,
      :root[data-olvend-theme="light"] .modal .status-warning {
        color: #b54708 !important;
        background: rgba(255, 182, 72, 0.12) !important;
        border-color: rgba(255, 182, 72, 0.36) !important;
      }

      :root[data-olvend-theme="light"] .modal .badge.bad,
      :root[data-olvend-theme="light"] .modal .helper-line.error,
      :root[data-olvend-theme="light"] .modal .status-error {
        color: #b42318 !important;
        background: rgba(255, 91, 102, 0.1) !important;
        border-color: rgba(255, 91, 102, 0.36) !important;
      }

      :root[data-olvend-theme="light"] .modal .close-btn,
      :root[data-olvend-theme="light"] .modal .modal-close-btn,
      :root[data-olvend-theme="light"] .modal .icon-btn {
        color: #17212b !important;
        background: rgba(15, 23, 42, 0.04) !important;
        border-color: rgba(15, 23, 42, 0.14) !important;
      }

      :root[data-olvend-theme="light"] .panel,
      :root[data-olvend-theme="light"] .panel-shell,
      :root[data-olvend-theme="light"] .table-shell,
      :root[data-olvend-theme="light"] .table-wrap,
      :root[data-olvend-theme="light"] .summary-box,
      :root[data-olvend-theme="light"] .summary-card,
      :root[data-olvend-theme="light"] .stat-card,
      :root[data-olvend-theme="light"] .content-card,
      :root[data-olvend-theme="light"] .widget,
      :root[data-olvend-theme="light"] .card {
        background: #ffffff !important;
        border-color: rgba(15, 23, 42, 0.12) !important;
        box-shadow: 0 16px 38px rgba(15, 23, 42, 0.08) !important;
      }

      :root[data-olvend-theme="light"] thead,
      :root[data-olvend-theme="light"] th,
      :root[data-olvend-theme="light"] .stock-excel-table th,
      :root[data-olvend-theme="light"] .dashboard-table th,
      :root[data-olvend-theme="light"] .excel-table th {
        background: #eef2f7 !important;
        color: #344054 !important;
        border-color: rgba(15, 23, 42, 0.14) !important;
      }

      :root[data-olvend-theme="light"] tbody tr,
      :root[data-olvend-theme="light"] .stock-excel-table tbody tr,
      :root[data-olvend-theme="light"] .dashboard-table tbody tr,
      :root[data-olvend-theme="light"] .excel-table tbody tr {
        background: #ffffff !important;
      }

      :root[data-olvend-theme="light"] tbody tr:nth-child(even),
      :root[data-olvend-theme="light"] .stock-excel-table tbody tr:nth-child(even),
      :root[data-olvend-theme="light"] .dashboard-table tbody tr:nth-child(even),
      :root[data-olvend-theme="light"] .excel-table tbody tr:nth-child(even) {
        background: #f8fafc !important;
      }

      :root[data-olvend-theme="light"] tbody tr:hover,
      :root[data-olvend-theme="light"] .stock-excel-table tbody tr:hover,
      :root[data-olvend-theme="light"] .dashboard-table tbody tr:hover,
      :root[data-olvend-theme="light"] .excel-table tbody tr:hover {
        background: #f1f5f9 !important;
      }

      :root[data-olvend-theme="light"] td,
      :root[data-olvend-theme="light"] td strong,
      :root[data-olvend-theme="light"] .name-strong,
      :root[data-olvend-theme="light"] .list-title,
      :root[data-olvend-theme="light"] .summary-box-value,
      :root[data-olvend-theme="light"] .stat-value,
      :root[data-olvend-theme="light"] .kpi-value {
        color: #17212b !important;
      }

      :root[data-olvend-theme="light"] .summary-box-label,
      :root[data-olvend-theme="light"] .summary-box-note,
      :root[data-olvend-theme="light"] .subtext,
      :root[data-olvend-theme="light"] .status-line,
      :root[data-olvend-theme="light"] .table-note {
        color: #475467 !important;
      }

      :root[data-olvend-theme="light"] .status-line.success {
        color: #067647 !important;
        font-weight: 800 !important;
      }

      :root[data-olvend-theme="light"] .status-line.error {
        color: #b42318 !important;
        font-weight: 800 !important;
      }

      :root[data-olvend-theme="light"] .badge.ok,
      :root[data-olvend-theme="light"] .badge.active,
      :root[data-olvend-theme="light"] .badge.good,
      :root[data-olvend-theme="light"] .badge.success {
        color: #027a48 !important;
        background: rgba(46, 204, 113, 0.14) !important;
        border-color: rgba(46, 204, 113, 0.36) !important;
      }

      :root[data-olvend-theme="light"] .badge.service_needed,
      :root[data-olvend-theme="light"] .badge.return_with_part,
      :root[data-olvend-theme="light"] .badge.warn,
      :root[data-olvend-theme="light"] .badge.warning {
        color: #b54708 !important;
        background: rgba(255, 182, 72, 0.14) !important;
        border-color: rgba(255, 182, 72, 0.38) !important;
      }

      :root[data-olvend-theme="light"] .badge.offline,
      :root[data-olvend-theme="light"] .badge.inactive,
      :root[data-olvend-theme="light"] .badge.bad,
      :root[data-olvend-theme="light"] .badge.danger {
        color: #b42318 !important;
        background: rgba(255, 91, 102, 0.12) !important;
        border-color: rgba(255, 91, 102, 0.38) !important;
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
          <div class="release-role-switch" id="releaseRoleSwitch">
            <button class="active" type="button" data-release-role="operator">Operátorka</button>
            <button type="button" data-release-role="warehouse">Sklad</button>
            <button type="button" data-release-role="management">Vedení</button>
          </div>
          <div class="release-body">
            <div id="releaseRoleContent"></div>
            <div class="release-note">Po potvrzení se okno na tomto zařízení znovu neukáže.</div>
          </div>
          <div class="release-footer">
            <button class="release-btn primary" type="button" id="releaseConfirmBtn">Začít používat ${version}</button>
          </div>
        </div>
      </div>
    `;
  }

  function setupReleaseNotes(force = false) {
    const currentVersion = extractVersionNumber(meta.versionValue);
    if (!currentVersion) return;
    if (compareVersions(currentVersion, MIN_RELEASE_ANNOUNCEMENT) < 0) return;

    const notes = RELEASE_NOTES[currentVersion];
    if (!notes) return;

    const seenVersion = localStorage.getItem(RELEASE_NOTES_KEY);
    if (!force && seenVersion === currentVersion) return;

    const wrapper = document.createElement("div");
    wrapper.innerHTML = renderReleaseModal(currentVersion, notes);
    document.body.appendChild(wrapper.firstElementChild);

    const backdrop = document.getElementById("releaseBackdrop");
    const confirmBtn = document.getElementById("releaseConfirmBtn");
    if (!backdrop || !confirmBtn) return;

    const roleContent = {
      operator: { note: "Přehled pro operátorku", items: ["Trasa, zastávky a práce u automatu jsou na jednom místě.", "Cílená inventura ukáže jen rizikové položky.", "Nový mobilní Sklad vede převzetí, nakládku, vrácení i odpis.", "Rozpracovaná práce lépe zvládá slabý signál."], rule: "Skutečné doplnění, inventura i výjimka se zapisují přímo v kroku, kde vznikly." },
      warehouse: { note: "Přehled pro skladníka", items: ["U vychystání je vidět, kdo zboží připravil a převzal.", "Expirace pracují s dostupnými šaržemi a dřívějším datem.", "Použitelné vratky a neprodejné odpisy jsou oddělené.", "Dodávky partnerům přicházejí rovnou do skladové fronty."], rule: "Sklad a vozidlo se mění až potvrzeným pohybem se skutečným množstvím." },
      management: { note: "Přehled pro vedení a kontrolu", items: ["Trasy porovnávají plán, návštěvy, čas a svoz.", "Inventurní rozdíly mají vysvětlení a konečné rozhodnutí.", "Telemetrie pomáhá plánovat návštěvy podle zásob a prodejů.", "Požadavky a partnerské dodávky mají společnou historii."], rule: "Výjimky zůstávají průchodné, ale vždy dohledatelné." }
    };
    const renderRole = (role) => {
      const data = roleContent[role] || roleContent.operator;
      const host = document.getElementById("releaseRoleContent");
      if (!host) return;
      host.innerHTML = `<p class="release-role-note">${data.note}</p><ul class="release-list">${data.items.map((item) => `<li>${item}</li>`).join("")}</ul><div class="release-rule">${data.rule}</div>`;
    };
    document.getElementById("releaseRoleSwitch")?.addEventListener("click", (event) => {
      const button = event.target.closest("[data-release-role]");
      if (!button) return;
      document.querySelectorAll("[data-release-role]").forEach((item) => item.classList.toggle("active", item === button));
      renderRole(button.dataset.releaseRole);
    });
    renderRole("operator");

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
        if (!nextCollapsed) {
          root.querySelectorAll(".nav-item-shell.has-children").forEach((otherShell) => {
            if (otherShell === shell) return;
            otherShell.classList.add("collapsed");
            const otherButton = otherShell.querySelector(":scope > .nav-link-row [data-collapse-nav]");
            if (otherButton) {
              otherButton.setAttribute("aria-expanded", "false");
              otherButton.setAttribute("title", "Rozbalit");
            }
          });
        }
        shell.classList.toggle("collapsed", nextCollapsed);
        button.setAttribute("aria-expanded", nextCollapsed ? "false" : "true");
        button.setAttribute("title", nextCollapsed ? "Rozbalit" : "Sbalit");
        setNavGroupCollapsed(key, nextCollapsed);
      });
    });
  }

  async function refreshMailUnreadBadge(refreshMailbox = true) {
    const badges = document.querySelectorAll("[data-mail-unread]");
    if (!badges.length) return;
    try {
      const { supabase } = await import("./supabase.js");
      const renderCount = async () => {
        const { count, error } = await supabase.from("mail_message_index").select("id", { count: "exact", head: true }).eq("folder_path", "INBOX").eq("is_read", false);
        if (error) throw error;
        const unread = Number(count || 0);
        badges.forEach((badge) => {
          badge.hidden = unread < 1;
          badge.textContent = unread > 99 ? "99+" : String(unread);
          badge.setAttribute("aria-label", `${unread} nepřečtených e-mailů`);
        });
      };
      await renderCount();
      const refreshKey = "olvendMailSidebarSyncAt";
      const lastRefresh = Number(sessionStorage.getItem(refreshKey) || 0);
      if (refreshMailbox && Date.now() - lastRefresh > 5 * 60 * 1000) {
        sessionStorage.setItem(refreshKey, String(Date.now()));
        try {
          const { mailApi } = await import("./mail-api.js");
          await mailApi("/sync", { method: "POST", body: "{}", timeoutMs: 75000 });
          await renderCount();
        } catch (_) {}
      }
    } catch (_) {}
  }

  initTheme();
  initializeCompactSidebar();

  const sidebar = document.querySelector(".sidebar");
  if (sidebar) {
    injectSidebarReorderStyles();
    sidebar.innerHTML = renderSidebar();
    setupSidebarCollapsing(sidebar);
    sidebar.querySelector("#openReleaseNotesButton")?.addEventListener("click", () => setupReleaseNotes(true));
    refreshMailUnreadBadge();
  }

  window.addEventListener("olvend-mail-unread-changed", () => refreshMailUnreadBadge(false));

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
