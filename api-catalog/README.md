# 📋 API Catalog — Guía de Despliegue (Instructor)

## Descripción

Este directorio contiene todo lo necesario para desplegar el **catálogo centralizado de APIs** en Amazon S3 como sitio web estático. Los estudiantes publicarán sus APIs aquí durante el laboratorio.

## Pre-requisitos

- AWS CLI v2 configurado con permisos de administrador
- Acceso a la cuenta AWS del laboratorio
- `curl` instalado (para descargar Swagger UI)

## Configuración

Editar `config.env` con los valores de tu entorno:

```bash
CATALOG_BUCKET_NAME=api-catalog-sesion4      # Nombre del bucket S3
AWS_REGION=us-east-1                          # Región AWS
NUM_STUDENTS=35                               # Número de estudiantes
```

## Despliegue

```bash
cd api-catalog
chmod +x deploy-catalog.sh
./deploy-catalog.sh
```

### ¿Qué hace `deploy-catalog.sh`?

1. ✅ Crea el bucket S3
2. ✅ Habilita Static Website Hosting
3. ✅ Configura CORS (necesario para Swagger UI)
4. ✅ Configura Bucket Policy (lectura pública)
5. ✅ Descarga Swagger UI dist (si no existe)
6. ✅ Genera `manifest.json` con sufijos 01-35
7. ✅ Sube todo el frontend (HTML + CSS + JS + Swagger UI)
8. ✅ Muestra la URL del catálogo

### Crear IAM Role para Lambda

Además del catálogo, debes crear un IAM Role que los Lambdas de los estudiantes usarán:

```bash
aws iam create-role \
  --role-name lab-lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam attach-role-policy \
  --role-name lab-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Obtener el ARN del role (compartir con estudiantes)
aws iam get-role --role-name lab-lambda-role --query 'Role.Arn' --output text
```

## Verificación

Abrir en navegador:
```
http://{CATALOG_BUCKET_NAME}.s3-website-{AWS_REGION}.amazonaws.com
```

## Información para compartir con estudiantes

| Variable | Valor |
|----------|-------|
| `CATALOG_BUCKET` | (nombre del bucket) |
| `LAMBDA_ROLE_ARN` | (ARN del role) |
| `AWS_REGION` | `us-east-1` |
| **URL del catálogo** | (URL del sitio S3) |

## Limpieza (post-clase)

```bash
chmod +x destroy-catalog.sh
./destroy-catalog.sh
```
