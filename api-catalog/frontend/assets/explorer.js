// ============================================================
// explorer.js — API Explorer with Swagger UI
// ============================================================

async function loadExplorer() {
  const params = new URLSearchParams(window.location.search);
  const suffix = params.get("suffix");
  
  if (!suffix) {
    document.getElementById("api-name").textContent = "Error: No se especificó suffix";
    return;
  }
  
  try {
    // Load metadata
    const metaRes = await fetch(`catalog/${suffix}/metadata.json`);
    if (!metaRes.ok) throw new Error("Metadata no encontrado");
    const metadata = await metaRes.json();
    
    // Update header
    document.getElementById("api-name").textContent = metadata.apiName;
    
    const badgeClass = getBadgeClass(metadata.statusCode);
    const apiInfo = document.getElementById("api-info");
    apiInfo.innerHTML = `
      <div class="info-item">
        <span class="badge ${badgeClass}">${metadata.status}</span>
      </div>
      <div class="info-item">
        <span>📌 v${metadata.version}</span>
      </div>
      <div class="info-item">
        <span class="badge badge-cloud">${metadata.cloudIcon || ""} ${metadata.cloud}</span>
      </div>
      <div class="info-item">
        <span>${metadata.apiKeyRequired ? "🔐 API Key requerido" : "🔓 Sin API Key"}</span>
      </div>
      ${metadata.stages?.test ? `
        <div class="info-item">
          <span>🧪 Test: <code>${metadata.stages.test}</code></span>
        </div>
      ` : ""}
      ${metadata.stages?.prod ? `
        <div class="info-item">
          <span>🚀 Prod: <code>${metadata.stages.prod}</code></span>
        </div>
      ` : ""}
    `;
    
    // Update page title
    document.title = `📖 ${metadata.apiName} — API Explorer`;
    
    // Initialize Swagger UI
    const openApiUrl = `catalog/${suffix}/openapi.json`;
    
    SwaggerUIBundle({
      url: openApiUrl,
      dom_id: "#swagger-container",
      presets: [
        SwaggerUIBundle.presets.apis,
        SwaggerUIStandalonePreset
      ],
      layout: "StandaloneLayout",
      deepLinking: true,
      showExtensions: true,
      showCommonExtensions: true,
      tryItOutEnabled: true,
    });
    
  } catch (error) {
    document.getElementById("api-name").textContent = "Error";
    document.getElementById("api-info").innerHTML = `
      <div class="info-item" style="color: #ff5252;">
        ❌ ${error.message}. Esta API aún no ha sido publicada en el catálogo.
      </div>
    `;
    document.getElementById("swagger-container").innerHTML = `
      <div style="padding: 3rem; text-align: center; color: #666;">
        <h2>API no disponible</h2>
        <p>El estudiante con suffix "${new URLSearchParams(window.location.search).get("suffix")}" 
           aún no ha completado el pipeline del contrato.</p>
        <p><a href="index.html">← Volver al catálogo</a></p>
      </div>
    `;
  }
}

function getBadgeClass(statusCode) {
  switch (statusCode) {
    case "MOCK": return "badge-mock";
    case "IMPLEMENTADO": return "badge-implemented";
    case "PRODUCCION": return "badge-production";
    default: return "badge-pending";
  }
}

// Initial load
loadExplorer();
