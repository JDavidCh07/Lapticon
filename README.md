# Lapticon

Lapticon es una aplicación académica para Android que conecta remitentes con viajeros para transportar encomiendas. Una misma cuenta permite enviar paquetes y aceptar envíos de otras personas sin cambiar de sesión.

## Aplicación

La navegación se divide en **Encomiendas**, **Viajes** y **Perfil**. Incluye registro e inicio de sesión, edición del perfil, publicación de encomiendas, registro de vuelos, seguimiento de entregas e históricos de envíos propios y viajes.

Las encomiendas contienen origen, destino, descripción, moneda y valor ofrecido. El perfil reúne nombre, apellido, teléfono, nacionalidad y fecha de nacimiento opcional.

## Tecnologías

La aplicación utiliza **Flutter y Dart**, componentes Material mediante `material_ui`, **Firebase Authentication** para autenticación y persistencia de sesión, y el paquete `http` para comunicarse con los servicios. El estado de las pantallas se maneja con `setState` y `FutureBuilder`.

## Funcionamiento

Los viajes se registran a partir del código de vuelo y su fecha. **AeroDataBox** proporciona la ruta, que permanece fija después de consultar el vuelo. Las encomiendas se filtran según las ciudades y las fechas informadas por el servidor, excluyendo las propias, vencidas o ya asignadas.

El viajero decide cuáles aceptar y puede consultar el nombre del remitente cuando esté disponible. Cada cuenta tiene un viaje disponible a la vez, con hasta **tres encomiendas**. La recepción se cierra al alcanzar ese límite o al comenzar el día del vuelo, según la fecha local del dispositivo; también puede cerrarse manualmente. El cierre se sincroniza al consultar los viajes y se revisa a medianoche mientras la aplicación está abierta.

El seguimiento es **Disponible → Tomada → Entregada**. La etapa final utiliza `recibida` en la API. Cerrar la recepción marca el viaje como `completado`, pero sus encomiendas continúan pendientes hasta registrar la entrega. Estas permanecen visibles y bloquean otro viaje mientras haya entregas por completar.

El remitente consulta sus envíos finalizados en el histórico de encomiendas. El histórico de viajes muestra los completados y cancelados.

## Conexiones

**Firebase Authentication** proporciona el token de identidad utilizado en las solicitudes protegidas a [Lapticon](https://lapticon-backend.onrender.com). El backend gestiona perfiles, viajes, encomiendas y sus estados; sus endpoints están descritos en la [documentación de la API](https://lapticon-backend.onrender.com/api-docs/).

La consulta de vuelos sigue el flujo **app → AeroDataBox → app → Lapticon**. AeroDataBox utiliza una clave de RapidAPI, independiente del token de Firebase.

| Servicio | Endpoints principales |
|---|---|
| Perfiles | `/api/users/register` y `/api/users/{uid}` |
| Viajes | `/api/viajes` y `/api/viajes/{id}/estado` |
| Encomiendas | `/api/encomiendas`, `/disponibles`, `/disponibles2` y `/buscar`, estos últimos bajo `/api/encomiendas` |
| Aceptación y entrega | `/api/encomiendas/tomar/{id}` y `/api/encomiendas/{id}/estado` |
| Vuelos | `aerodatabox.p.rapidapi.com/flights/number/{codigo}/{fecha}` |

## Organización del código

| Ubicación | Responsabilidad |
|---|---|
| `lib/main.dart` y `lib/config.dart` | Inicio, sesión, navegación y configuración de servicios. |
| `lib/models.dart` | Datos, fechas, ciudades y compatibilidad. |
| `lib/screens/` | Pantallas, formularios, detalles e históricos. |
| `lib/services/` | Comunicación con Lapticon y AeroDataBox. |
| `lib/widgets/` | Componentes y diseño compartidos. |
| `android/` y `Recursos/` | Configuración Android y material académico de referencia. |
| `pubspec.yaml` y `aerodata.json` | Dependencias y configuración de acceso a AeroDataBox. |

## Flujo de prueba funcional

Una cuenta remitente publica una encomienda y otra cuenta registra un vuelo de la misma ruta con una fecha compatible. El envío aparece entre las opciones del viajero, quien consulta sus detalles y lo acepta. El remitente observa entonces el estado Tomada y la asignación del viajero.

Tras cerrar la recepción y entregar el paquete, el viajero confirma la entrega. El envío pasa a Entregada y aparece en el histórico del remitente. Los envíos propios o incompatibles no se ofrecen para aceptar, y las entregas pendientes permanecen visibles aunque el viaje esté completado.
