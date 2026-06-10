// ============================================================
// catalog.js — API Catalog Frontend Logic
// ============================================================

const CATALOG_BASE = "catalog";
let allApis = [];

async function loadCatalog() {
  const tbody = document.getElementById("catalog-body");
  
  try {
    // Load manifest
    const manifestRes = await fetch("manifest.json");
    const suffixes = await manifestRes.json();
    
    // Load metadata for each suffix
    const promises = suffixes.map(async (suffix) => {
      try {
        const res = await fetch(`${CATALOG_BASE}/${suffix}/metadata.json`);
        if (res.ok) {
          return await res.json();
        }
      } catch (e) {
        // API not yet published
      }
      return {
        suffix: suffix,
        apiName: `cuentas-api-${suffix}`,
        status: "⚪ PENDIENTE",
        statusCode: "PENDIENTE",
        version: "—",
        cloud: "—",
        cloudIcon: "",
        apiKeyRequired: false,
        timestamps: { lastUpdated: null }
      };
    });
    
    allApis = await Promise.all(promises);
    renderTable(allApis);
    renderStats(allApis);
    setupFilters();
    
  } catch (error) {
    tbody.innerHTML = `<tr><td colspan="8" class="loading">Error al cargar el catálogo: ${error.message}</td></tr>`;
  }
}

function renderTable(apis) {
  const tbody = document.getElementById("catalog-body");
  
  tbody.innerHTML = apis.map(api => {
    const badgeClass = getBadgeClass(api.statusCode);
    const hasOpenApi = api.statusCode !== "PENDIENTE";
    const lastUpdated = api.timestamps?.lastUpdated 
      ? new Date(api.timestamps.lastUpdated).toLocaleString("es-PE", { 
          dateStyle: "short", timeStyle: "short" 
        })
      : "—";
    
    return `
      <tr data-status="${api.statusCode}">
        <td><strong>${api.suffix}</strong></td>
        <td>${api.apiName}</td>
        <td><span class="badge ${badgeClass}">${api.status}</span></td>
        <td>${api.version || "—"}</td>
        <td><span class="badge badge-cloud">${api.cloudIcon || ""} ${api.cloud || "—"}</span></td>
        <td>${api.apiKeyRequired ? "🔐" : "—"}</td>
        <td>${lastUpdated}</td>
        <td>
          ${hasOpenApi 
            ? `<a href="explorer.html?suffix=${api.suffix}" class="btn-explore">📖 Explorar</a>` 
            : `<span class="btn-explore btn-disabled">⏳ Pendiente</span>`
          }
        </td>
      </tr>
    `;
  }).join("");
}

function renderStats(apis) {
  const stats = document.getElementById("stats");
  const counts = {
    total: apis.length,
    mock: apis.filter(a => a.statusCode === "MOCK").length,
    impl: apis.filter(a => a.statusCode === "IMPLEMENTADO").length,
    prod: apis.filter(a => a.statusCode === "PRODUCCION").length,
    pending: apis.filter(a => a.statusCode === "PENDIENTE").length,
  };
  
  stats.innerHTML = `
    <div class="stat-item">
      <span>Total:</span>
      <span class="stat-count">${counts.total}</span>
    </div>
    <div class="stat-item">
      <span>🟡 Mock:</span>
      <span class="stat-count">${counts.mock}</span>
    </div>
    <div class="stat-item">
      <span>🔵 Implementado:</span>
      <span class="stat-count">${counts.impl}</span>
    </div>
    <div class="stat-item">
      <span>🟢 Producción:</span>
      <span class="stat-count">${counts.prod}</span>
    </div>
    <div class="stat-item">
      <span>⚪ Pendiente:</span>
      <span class="stat-count">${counts.pending}</span>
    </div>
  `;
}

function getBadgeClass(statusCode) {
  switch (statusCode) {
    case "MOCK": return "badge-mock";
    case "IMPLEMENTADO": return "badge-implemented";
    case "PRODUCCION": return "badge-production";
    default: return "badge-pending";
  }
}

function setupFilters() {
  const buttons = document.querySelectorAll(".filter-btn");
  buttons.forEach(btn => {
    btn.addEventListener("click", () => {
      buttons.forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      
      const filter = btn.dataset.filter;
      if (filter === "all") {
        renderTable(allApis);
      } else {
        renderTable(allApis.filter(a => a.statusCode === filter));
      }
    });
  });
}

// Auto-refresh every 30 seconds
setInterval(loadCatalog, 30000);

// Initial load
loadCatalog();
