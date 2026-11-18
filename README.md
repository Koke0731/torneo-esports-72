# Proyecto 72: Torneo de Esports

Sistema Erlang/OTP para gestión de torneos de videojuegos con brackets, partidas simultáneas y marcadores en vivo.

## Stack Tecnológico

- **Backend**: Erlang/OTP 26+
- **Web Server**: Cowboy 2.12
- **JSON**: Jiffy
- **Logging**: Lager
- **Diagnostics**: Recon
- **Build**: Rebar3
- **Frontend**: Google Stitch (diseño UI)

## Arquitectura OTP

```
p72_torneo_de_esports_sup (top-level, one_for_one)
├── p72_torneo_de_esports_server (gen_server)  # Compatibilidad base: ping/state
├── tournament_registry (gen_server)          # Gestión de torneos
├── tournament_sup_manager (supervisor)       # Crea un supervisor por torneo
│   └── tournament_sup (per torneo, one_for_one)
│       ├── bracket_server (gen_server)       # Lógica de cuadros
│       ├── match_sup (dynamic_supervisor)    # Supervisa partidas
│       │   └── match_server (gen_statem)     # scheduled → in_play → finished
│       ├── live_score_server (gen_server)    # Scores tiempo real + WS
│       ├── tournament_process (gen_statem)   # registration → in_progress → completed
│       └── dispute_resolver (gen_server)     # Resolución de conflictos
├── metrics_collector (gen_server)            # Métricas /metrics
└── http_server (ranch listener supervisor)   # Cowboy REST + WebSocket
```

## Formatos de Torneo Soportados

| Formato | Descripción | Partidas |
|---------|-------------|----------|
| `single_elim` | Eliminación simple | N-1 |
| `double_elim` | Doble eliminación (winners/losers bracket) | ~2N-2 |
| `swiss` | Valor reconocido por el modelo; flujo no validado | Pendiente |
| `groups` | Valor reconocido por el modelo; flujo no validado | Pendiente |

La generación y el avance verificados corresponden a eliminación simple y doble. No se debe presentar suizo ni grupos como formatos terminados.

## Series

- `bo1` - Best of 1
- `bo3` - Best of 3
- `bo5` - Best of 5

## Cómo ejecutar el proyecto (guía rápida)

### Requisitos

| Herramienta | Versión | Comprobación |
|---|---|---|
| Erlang/OTP | 26 o superior | `erl -version` |
| rebar3 | 3.22 o superior | `rebar3 version` |
| git | reciente | `git --version` |
| curl | opcional (probar la API) | `curl --version` |

En Ubuntu 22.04/24.04, la forma más directa de tener OTP 26 es [kerl](https://github.com/kerl/kerl) (así se aprovisionó la instancia del proyecto) o los paquetes de [Erlang Solutions](https://www.erlang-solutions.com/downloads/). El proyecto no necesita base de datos: todo el estado vive en memoria.

### 1. Clonar el repositorio

```bash
git clone https://github.com/Koke0731/torneo-esports-72.git
cd torneo-esports-72
```

Este repositorio contiene únicamente la entrega del proyecto #72 (rama `main`).

### 2. Compilar

```bash
rebar3 compile
```

### 3. Ejecutar las pruebas

```bash
rebar3 eunit     # 17 pruebas
rebar3 xref      # referencias cruzadas
```

**Grabación de las pruebas (asciinema):** [rebar3 eunit — 17 tests, 0 failures](https://asciinema.org/a/lJ38O03Z10TLciAk)

```markdown
[![asciicast](https://asciinema.org/a/lJ38O03Z10TLciAk.svg)](https://asciinema.org/a/lJ38O03Z10TLciAk)
```

### 4. Arrancar en desarrollo

```bash
rebar3 shell
```

La aplicación escucha en el puerto **8080** (se define en `config/sys.config`). Con ella iniciada:

| Recurso | URL |
|---|---|
| Dashboard | <http://localhost:8080/> |
| Health check | <http://localhost:8080/health> |
| API de torneos | <http://localhost:8080/api/torneos> |
| Métricas | <http://localhost:8080/metrics> |

Para salir de la shell de Erlang: `q().`

### 5. Arrancar como release (sin shell)

```bash
rebar3 as prod release
_build/prod/rel/p72_torneo_de_esports/bin/p72_torneo_de_esports foreground
```

En segundo plano usa `daemon` en lugar de `foreground`. Para detenerlo:

```bash
_build/prod/rel/p72_torneo_de_esports/bin/p72_torneo_de_esports stop
```

### 6. Verificar que responde

```bash
curl -s http://localhost:8080/health
# {"timestamp":1794344628,"status":"ok"}

curl -s http://localhost:8080/api/torneos
# {"tournaments":[]}
```

### 7. Servicio systemd (instancia del proyecto)

En la VM del proyecto el release está instalado como servicio:

```bash
sudo systemctl status p72-esports
sudo systemctl restart p72-esports
sudo journalctl -u p72-esports -f
```

### Problemas comunes

| Síntoma | Causa / solución |
|---|---|
| `rebar3: command not found` | añade rebar3 al `PATH` o instálalo desde <https://rebar3.org/> |
| `eaddrinuse` / puerto ocupado | algo usa el 8080: `ss -ltnp \| grep 8080`; cambia `http_port` en `config/sys.config` |
| El dashboard carga pero la API falla | revisa `journalctl -u p72-esports` o la consola de Erlang |
| Los cambios no aparecen | recompila con `rebar3 compile` y reinicia el release o el servicio |

## Frontend

Con la aplicación iniciada, el dashboard está disponible en `http://localhost:8080/`.
En la instancia de proyecto desplegada se sirve en <http://35.93.5.143:8080/> (el puerto 8080 debe estar abierto; la IP pública puede cambiar si la VM se reinicia porque no tiene Elastic IP).
Incluye pestañas para torneos, brackets, equipos y partidas, disputas y marcadores en vivo.
El dashboard usa la API del mismo servidor (`/api/...`) y el WebSocket `/ws`.

La vista **Brackets** (también accesible con `?tab=brackets`) presenta cada cuadro como un árbol real: columnas por ronda alineadas en una cuadrícula, conectores ortogonales SVG entre ganadores y su siguiente partida, cabecera de ronda con progreso y navegador de rondas con “Ir a la final”. Cada tarjeta muestra dos equipos, marcador, formato y estado (`programada`, `en juego`, `finalizada`, `en disputa`, `descalificado`); al hacer clic se abre la partida en la pestaña Partidas. El panel es desplazable horizontalmente y los conectores se recalculan al cambiar de pestaña o al redimensionar la ventana.

Si Erlang corre en una VM de Corellium, mantén abierto un túnel SSH local hacia el puerto 8080 y abre el dashboard desde el equipo donde corre el túnel.

## API REST

### Torneos

```
POST   /api/torneos                    # Crear torneo
GET    /api/torneos                    # Listar torneos
GET    /api/torneos/:id                # Obtener torneo
DELETE /api/torneos/:id                # Eliminar torneo
POST   /api/torneos/:id/start          # Iniciar torneo
POST   /api/torneos/:id/finish         # Finalizar torneo
```

### Equipos

```
POST   /api/torneos/:id/equipos        # Registrar equipo
GET    /api/torneos/:id/equipos        # Listar equipos
```

### Brackets

```
GET    /api/torneos/:id/bracket        # Obtener todos los brackets
GET    /api/torneos/:id/bracket/:bid   # Obtener bracket específico
GET    /api/torneos/:id/bracket/progress # Progreso del bracket
```

### Partidas

```
GET    /api/torneos/:id/partidas       # Listar partidas (próximas)
GET    /api/torneos/:id/partidas/:mid  # Obtener partida
POST   /api/torneos/:id/partidas/:mid/start  # Iniciar partida
POST   /api/torneos/:id/partidas/:mid/resultado  # Enviar resultado
POST   /api/torneos/:id/partidas/:mid/marcador   # Publicar marcador en vivo (WS)
POST   /api/torneos/:id/partidas/:mid/dq        # Descalificar equipo
POST   /api/torneos/:id/partidas/:mid/no_show   # Reportar no-show
```

### Disputas

```
POST   /api/torneos/:id/partidas/:mid/disputa  # Reportar disputa
GET    /api/torneos/:id/disputas       # Listar disputas abiertas
POST   /api/torneos/:id/disputas/:did/resolver # Resolver disputa
POST   /api/torneos/:id/disputas/:did/resolver_recalc # Resolver y recalcular bracket
```

### Métricas

```
GET    /metrics                        # Métricas Prometheus-style
```

### Health Check

```
GET    /health                         # Health check
```

## WebSocket (Live Scores)

```
WS /ws?tournament_id=<id>
```

El `tournament_id` es el único parámetro de la URL; el filtro por partida se envía
en el mensaje `subscribe` (ver abajo). Sin filtro se recibe el resumen del torneo.

### Mensajes Cliente → Servidor

```json
{"type": "subscribe", "match_id": 1}          # Suscribirse a partida
{"type": "subscribe_tournament"}              # Suscribirse a torneo
{"type": "unsubscribe"}                       # Desuscribirse
{"type": "ping"}                              # Keepalive
```

### Mensajes Servidor → Cliente

```json
{"type": "score_update", "data": {...}}
{"type": "match_finished", "match_id": 1, "result": {...}}
{"type": "tournament_state", "data": {...}}
{"type": "pong", "timestamp": 1234567890}
```

## Ejemplo: Crear Torneo y Registrar Equipos

```bash
# Crear torneo
curl -X POST http://localhost:8080/api/torneos \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mi Torneo",
    "format": "double_elim",
    "series_format": "bo3",
    "max_teams": 16,
    "config": {
      "tables_count": 8,
      "match_duration_estimate": 45,
      "allow_disputes": true,
      "dispute_timeout": 300
    }
  }'

# Registrar equipos
curl -X POST http://localhost:8080/api/torneos/1/equipos \
  -H "Content-Type: application/json" \
  -d '{"name": "Team Alpha", "players": ["Player1", "Player2"], "seed": 1}'

# Iniciar torneo (genera brackets)
curl -X POST http://localhost:8080/api/torneos/1/start

# Ver bracket
curl http://localhost:8080/api/torneos/1/bracket

# Enviar resultado de partida
curl -X POST http://localhost:8080/api/torneos/1/partidas/1/resultado \
  -H "Content-Type: application/json" \
  -d '{
    "team_id": 1,
    "winner_team_id": 1,
    "loser_team_id": 2,
    "scores": [[1, 2], [2, 0], [1, 2]]
  }'
```

### Demo del escenario de 64 equipos

Con la aplicación iniciada, ejecuta el simulador desde otra terminal:

```bash
python3 -m pip install websockets
python3 scripts/scenario_demo.py --base-url http://localhost:8080
```

El script crea un torneo de doble eliminación con 64 equipos y 8 mesas configuradas, conecta 300 espectadores WebSocket reales, registra dos resultados opuestos para abrir una disputa y descalifica a un equipo en otra partida. Al final comprueba que el rival del equipo descalificado aparece en la segunda ronda. Las conexiones de espectadores permanecen abiertas 60 segundos; usa `--hold-seconds 0` para cerrarlas al terminar o `--hold-seconds 300` para mantenerlas cinco minutos.

El torneo queda en memoria después de la demo; elimínalo desde el Dashboard al terminar. La aplicación guarda el número de mesas en la configuración y expone `assign_table/4` y `assign_referee/4` en `p72_match_sup` (con su prueba de reserva concurrente), pero esa asignación **no se dispara automáticamente** al iniciar una partida: aún debe invocarse desde la API o un futuro planificador.

## Métricas Disponibles (/metrics)

- `tournaments_total` - Total torneos creados
- `tournaments_active` - Torneos en curso
- `matches_total` - Total partidas
- `matches_in_progress` - Partidas en juego
- `matches_finished` - Partidas finalizadas
- `matches_disputed` - Partidas en disputa
- `viewers_total` - Espectadores WebSocket conectados (verificado: 50 conectados → 50, al desconectar → 0)
- `viewers_per_match` - Espectadores por partida. Solo cuenta clients suscritos con `subscribe` a un `match_id`; los que ven el resumen del torneo se contabilizan en `viewers_total` pero no aquí (verificado: 5 en partida 12 + 3 de resumen → `[{"match_id":12,"viewers":5}]`)
- `bracket_progress` - Progreso por torneo (0.0-1.0), publicado al adjudicar o disputar resultados

Todas las métricas se actualizan en vivo; `timestamp` refleja el último evento contabilizado.

## Resolución de Disputas

Cuando dos equipos reportan resultados contradictorios:
1. Sistema detecta conflicto automáticamente
2. Marca partida como `disputed`
3. Crea registro en `dispute_resolver`
4. Admin resuelve via API `/disputas/:id/resolver`
5. Bracket se recalcula con resultado oficial

## Tests de Caos

```bash
# Ejecutar todos los tests
rebar3 eunit

# Test específico
rebar3 eunit --module=p72_torneo_de_esports_tests --test=arbol_de_supervision_test
```

`rebar3 eunit` ejecuta 17 pruebas. El árbol del test omite el listener HTTP porque el entorno de pruebas no permite abrir sockets; se comprueba su child spec en el supervisor raíz.

Prueba de caos reproducible (`match_process_restarts_case`): mata con `kill` un proceso `p72_match_server`; espera un PID distinto y comprueba que el servidor de marcadores del torneo sigue vivo. El supervisor informa `reason: killed` y reinicia la partida. Esta prueba no mata el bracket ni simula una caída de la VM o de la red.

También se verifican: cierre automático de la final de eliminación simple, reapertura y cierre posterior al apelar un resultado, corrección de un resultado propagado en eliminación simple, byes con cinco equipos, reportes contradictorios y arbitraje administrativo, descalificación/no-show a nivel de proceso, reserva concurrente de mesa y árbitro, doble eliminación con 64 equipos y final reiniciada, y 300 procesos espectadores que reciben un marcador en menos de 2 segundos dentro de la misma VM.

Además de esa prueba unitaria, `scripts/scenario_demo.py` y `scripts/ws_load.py` validan el escenario contra el servidor desplegado con **300 conexiones WebSocket reales**. Medición de la última corrida: 300/300 clientes suscritos (0.340 s), ping/pong 300/300, evento `score_update` recibido por 300/300 en 0.022 s, latencia promedio 17.5 ms (máx. 21.5 ms). El estado sigue viviendo en memoria; no se ha probado una caída de VM ni una red con pérdida de paquetes.

### Entrega del problema #72

**Diseño OTP.** El registro y el supervisor dinámico administran la vida de cada torneo. Cada torneo supervisa su estado, bracket, marcador y disputas; cada partida usa un `gen_statem` para validar transiciones. El supervisor de partidas reinicia una partida caída sin reiniciar el bracket. El bracket mantiene los resultados y recalcula las rondas posteriores cuando se adjudica un resultado corregido. Al finalizar la final de eliminación simple el torneo pasa a `completed`; si el resultado se apela, vuelve a `in_progress` hasta que la disputa se resuelva. En doble eliminación reconstruye los cuadros y vuelve a reproducir los resultados que siguen siendo válidos para los mismos participantes. El administrador arbitra disputas; la aplicación no decide automáticamente quién dice la verdad.

**Escenario simulado.** EUnit genera 64 equipos, juega el cuadro de ganadores y perdedores hasta la final, hace que gane el campeón del cuadro de perdedores en la primera gran final y comprueba el reinicio y cierre del torneo. La ejecución final contiene 127 partidas (126 del formato más la final de reinicio). El test adicional registra 300 procesos locales como espectadores y mide la entrega de una actualización. El mismo escenario se reproduce contra el servidor en vivo con `scripts/scenario_demo.py`: 64 equipos, 8 mesas configuradas, 300 espectadores WebSocket reales, disputa por doble reporte y descalificación con avance del rival. No hay 8 mesas físicas: el número se guarda como configuración y se reserva mediante las funciones de asignación descritas arriba.

**Supuestos.** Las cifras de 64 equipos, 8 mesas y 300 espectadores son parámetros del enunciado, no mediciones de producción. El resultado de cada serie se representa como lista de mapas ganados; el árbitro autenticado aún no existe, así que el test invoca directamente la función administrativa. La descalificación y el no-show se modelan como victoria del rival. Los byes se verifican en eliminación simple con cinco equipos; un cuadro doble con tamaño no potencia de dos todavía requiere validación específica. Los procesos mantienen estado en memoria, por lo que un reinicio total pierde el torneo.

**Cifras verificadas/documentadas.** La eliminación simple de N participantes requiere N−1 partidas; para 64 equipos son 63. El cuadro doble generado contiene 63 partidas de ganadores, 62 de perdedores y una gran final: 126 partidas; el reinicio añade una y da 127. FACEIT documenta el reinicio de la gran final cuando el equipo del cuadro de perdedores vence al equipo invicto: [guía de formatos de eliminación simple y doble](https://support.faceit.com/hc/es/articles/17048704436508-Torneos-en-formato-de-eliminaci%C3%B3n-simple-y-doble) (consultada el 6 de noviembre de 2026). Los límites de 1–2 segundos y 300 espectadores del enunciado se usan como objetivo de la prueba local, no se citan como garantía medida en producción.

**Interfaz.** Las capturas exportadas de Stitch están en [`stitch_esports_tournament_hub/`](stitch_esports_tournament_hub/): dashboard, brackets, detalle de partida y bitácora. El frontend integrado en Cowboy toma esa dirección estética y la adapta a datos reales: superficies por capas, KPIs, pestañas, estados con color y un bracket de árbol con conectores. Las capturas del frontend real desplegado sobre el release de producción son [`docs/dashboard_en_vivo.png`](docs/dashboard_en_vivo.png) y [`docs/brackets_en_vivo.png`](docs/brackets_en_vivo.png). La verificación headless del escenario de 64 equipos midió 2 cuadros, 17 columnas de ronda, 125 tarjetas de partida y 123 conectores SVG, con KPIs `2/2`, `64/64`, `300` espectadores WebSocket y `1` disputa, sin errores JavaScript.

## Estructura de Directorios

```
├── config/
│   ├── sys.config      # Configuración app + lager
│   └── vm.args         # Parámetros VM Erlang
├── design/
│   ├── PROMPT_STITCH.md    # Prompt para Google Stitch
│   └── DESIGN.md           # Design system exportado desde Stitch
├── docs/
│   ├── dashboard_en_vivo.png  # Captura del dashboard desplegado
│   └── brackets_en_vivo.png   # Captura del bracket de árbol con conectores
├── problema/
│   └── readme.md       # Descripción del problema
├── src/
│   ├── p72_torneo_de_esports.app.src
│   ├── p72_torneo_de_esports_app.erl
│   ├── p72_torneo_de_esports_sup.erl
│   ├── p72_torneo_de_esports_server.erl    # Compatibilidad base: ping/state
│   ├── p72_torneo_de_esports.hrl         # Records de dominio
│   ├── p72_tournament_registry.erl       # Registro de torneos
│   ├── p72_tournament_sup.erl            # Supervisores por torneo
│   ├── p72_bracket_server.erl            # Lógica de brackets
│   ├── p72_match_sup.erl                 # Supervisor dinámico de partidas
│   ├── p72_match_server.erl              # gen_statem por partida
│   ├── p72_live_score_server.erl         # Scores tiempo real
│   ├── p72_tournament_process.erl        # Estado torneo (gen_statem)
│   ├── p72_dispute_resolver.erl          # Resolución disputas
│   ├── p72_metrics_collector.erl         # Métricas globales
│   ├── p72_http_handler.erl              # REST API (Cowboy)
│   └── p72_ws_handler.erl                # WebSocket (Cowboy)
├── test/
│   └── p72_torneo_de_esports_tests.erl   # EUnit tests
├── rebar.config
├── .gitignore
└── README.md
```

## Estado de Entrega y Trabajo Futuro

### Completado para la entrega del problema #72

- [x] Diseño OTP: registry, supervisors por torneo/partida, `gen_statem`, marcador, disputas, métricas
- [x] Pantallas Stitch (Dashboard, Brackets, Detalle, Bitácora) + frontend integrado en Cowboy
- [x] API REST + WebSocket `/ws`, `/metrics` y `/health`
- [x] Release `rebar3 as prod release` + servicio systemd (`p72-esports`)
- [x] Simulación 64 equipos / doble eliminación / 300 espectadores (`scripts/scenario_demo.py`, `scripts/ws_load.py`)
- [x] Prueba de caos y `rebar3 compile` / `rebar3 eunit` en verde (17 pruebas)
- [x] Grabación asciinema de los tests

### Trabajo futuro (fuera del alcance de la entrega)

- [ ] Autenticación/Autorización (JWT) para reportar resultados y arbitrar disputas
- [ ] Persistencia (Mnesia/PostgreSQL): el estado actual vive en memoria
- [ ] Asignación/reserva automática de mesas y árbitros durante las partidas
- [ ] Formatos suizo y grupos (el modelo los reconoce; el flujo no está validado)
- [ ] Notificaciones push (FCM/APNS) e integración con Discord/Stream overlays
- [ ] Pruebas de carga de red (tsung/wrk) y contenedor Docker

## Licencia

MIT
