// ============================================================
// Lambda Handler — Cuentas Bancarias API
// Endpoint: GET /clientes/{clienteId}/cuentas
// ============================================================

export const handler = async (event) => {
  console.log("Event received:", JSON.stringify(event, null, 2));

  const clienteId = event.pathParameters?.['cliente-id'] || event.pathParameters?.clienteId;
  const httpMethod = event.httpMethod;

  // ── Headers CORS ──
  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, x-api-key, Idempotency-Key",
  };

  // ── Validar clienteId ──
  if (!clienteId) {
    return {
      statusCode: 400,
      headers,
      body: JSON.stringify({
        type: "https://api.banco.com/errors/validation",
        title: "Parámetro requerido faltante",
        status: 400,
        detail: "El parámetro 'cliente-id' es obligatorio.",
        instance: event.path,
      }),
    };
  }

  // ── GET /clientes/{clienteId}/cuentas ──
  if (httpMethod === "GET") {
    // Datos simulados (en producción vendrían de DynamoDB o RDS)
    const cuentas = {
      CLI001: [
        {
          numeroCuenta: "1234567890",
          tipo: "AHORROS",
          moneda: "PEN",
          titular: "Juan Pérez",
          saldo: 5000.0,
        },
        {
          numeroCuenta: "0987654321",
          tipo: "CORRIENTE",
          moneda: "USD",
          titular: "Juan Pérez",
          saldo: 1200.5,
        },
      ],
      CLI002: [
        {
          numeroCuenta: "1111222233",
          tipo: "AHORROS",
          moneda: "PEN",
          titular: "María García",
          saldo: 15000.0,
        },
      ],
    };

    const clienteCuentas = cuentas[clienteId];

    if (!clienteCuentas) {
      return {
        statusCode: 404,
        headers,
        body: JSON.stringify({
          type: "https://api.banco.com/errors/not-found",
          title: "Cliente no encontrado",
          status: 404,
          detail: `No se encontró el cliente con ID '${clienteId}'.`,
          instance: event.path,
        }),
      };
    }

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({
        clienteId: clienteId,
        cuentas: clienteCuentas,
      }),
    };
  }

  // ── POST /clientes/{clienteId}/cuentas (para Lab Propuesto) ──
  // --- LABORATORIO PROPUESTO: DESCOMENTAR PARA IMPLEMENTAR EL POST ---
  /*
  if (httpMethod === "POST") {
    let body;
    try {
      body = JSON.parse(event.body || "{}");
    } catch (e) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          type: "https://api.banco.com/errors/invalid-json",
          title: "JSON inválido",
          status: 400,
          detail: "El cuerpo de la solicitud no es un JSON válido.",
          instance: event.path,
        }),
      };
    }

    const { tipo, moneda, titular } = body;

    // Validación de campos requeridos
    if (!tipo || !moneda || !titular) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({
          type: "https://api.banco.com/errors/validation",
          title: "Campos requeridos faltantes",
          status: 400,
          detail: "Los campos 'tipo', 'moneda' y 'titular' son obligatorios.",
          instance: event.path,
        }),
      };
    }

    // Simular creación de cuenta
    const nuevaCuenta = {
      numeroCuenta: Math.floor(Math.random() * 10000000000).toString().padStart(10, '0'),
      tipo: tipo.toUpperCase(),
      moneda: moneda.toUpperCase(),
      titular: titular,
      saldo: 0.00,
      creadoEn: new Date().toISOString()
    };

    return {
      statusCode: 201,
      headers,
      body: JSON.stringify(nuevaCuenta),
    };
  }
  */

  // ── Método no soportado ──
  return {
    statusCode: 405,
    headers,
    body: JSON.stringify({
      type: "https://api.banco.com/errors/method-not-allowed",
      title: "Método no permitido",
      status: 405,
      detail: `El método ${httpMethod} no está soportado para este recurso.`,
      instance: event.path,
    }),
  };
};
