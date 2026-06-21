[![Open in Visual Studio Code](https://classroom.github.com/assets/open-in-vscode-2e0aaae1b6195c2367325f4f02e2d04e9abb55f0b24a779b69b11b9e10269abc.svg)](https://classroom.github.com/online_ide?assignment_repo_id=24120994&assignment_repo_type=AssignmentRepo)
# Lab04 - Visualización usando pantalla LCD 16x2

# Integrantes
- Brigitte Vanessa Quiñonez Capera
- Andrea Alejandra Suárez Cuervo

# Informe

Indice:

1. [Diseño implementado](#diseño-implementado)
2. [Simulaciones](#simulaciones)
3. [Implementación](#implementación)
4. [Conclusiones](#conclusiones)
5. [Referencias](#referencias)

## Diseño implementado
### Descripción
El laboratorio consiste en el diseño e implementación de un controlador para pantalla LCD 16x2 en modo paralelo de 8 bits, utilizando una Máquina de Estados Finitos (FSM) descrita en Verilog HDL e implementada sobre la FPGA Intel Cyclone IV EP4CE10E22C8.

El sistema se divide en dos partes. En la **Parte 1** se implementa un controlador capaz de mostrar texto estático en las dos filas de la pantalla ("Bateria 1" y "Bateria 2"). En la **Parte 2** se extiende el diseño para mostrar texto dinámico: los valores numéricos de dos entradas de 4 bits provenientes de los DIP switches de la tarjeta de desarrollo, actualizados en tiempo real.

El módulo principal `LCD1602_controller` está compuesto por tres bloques funcionales:

- **Divisor de frecuencia:** genera la señal `clk_16ms` a partir del reloj de 50 MHz de la FPGA, reduciendo la frecuencia a aproximadamente 30 Hz para respetar los tiempos mínimos de operación de la LCD.
- **FSM (unidad de control):** implementada con tres bloques `always`. El primero registra el estado actual, el segundo calcula el próximo estado de forma combinacional, y el tercero maneja el datapath (señales `rs`, `data` y contadores). El datapath usa `case(next_state)` en lugar de `case(fsm_state)` para evitar latencia de un ciclo en las salidas.
- **Memorias:** `config_mem` almacena los 4 comandos de inicialización de la LCD, y `static_data_mem` almacena los 32 bytes de texto estático cargados desde `data.txt` mediante `$readmemh`.

La señal `enable` de la LCD se conecta directamente a `clk_16ms` sin pasar por la FSM, de modo que cada flanco de esta señal actúa como pulso de captura para la LCD

### Diagramas
#### Diagrama de la FSM — Parte 1


![Diagrama FSM Parte 1](imagenes/fsm_p1.png)

#### Diagrama de arquitectura — Parte 1

<!-- Insertar imagen del diagrama de arquitectura (draw.io) aquí -->
![Diagrama de arquitectura Parte 1](./figs/arquitectura_p1.png)

#### Diagrama de la FSM — Parte 2

En la Parte 2 se agrega el estado `WR_DIN_TEXT`, que realiza un bucle sobre sí mismo indefinidamente para actualizar el texto dinámico en tiempo real. Internamente, este estado utiliza un sub-contador `sel_dinamic` que cicla por 6 sub-estados:

| Sub-estado | Acción |
|---|---|
| `SetCursor1` | Envía comando `0x8B`: mueve cursor a línea 1, posición 11 |
| `WR_DEC1` | Escribe la decena de `temp1` en ASCII |
| `WR_UNI1` | Escribe la unidad de `temp1` en ASCII |
| `SetCursor2` | Envía comando `0xCB`: mueve cursor a línea 2, posición 11 |
| `WR_DEC2` | Escribe la decena de `temp2` en ASCII |
| `WR_UNI2` | Escribe la unidad de `temp2` en ASCII |

La conversión de valor numérico a carácter ASCII se realiza como:

```
decenas = (valor / 10) + 0x30
unidades = (valor % 10) + 0x30


## Simulaciones
### Parte 1 — Texto estático

La simulación se realizó con Icarus Verilog y GTKWave. El testbench instancia el módulo con `COUNT_MAX = 50` para reducir el tiempo de simulación, y fija `ready_i = 1` para que la FSM arranque inmediatamente tras el reset.

```bash
iverilog -o lcd1602_sim test/lcd1602_TB.v
vvp lcd1602_sim
gtkwave LCD1602_controller_TB.vcd
```

En la simulación se observa:

- `clk_16ms` y `enable` oscilando correctamente como reloj lento de la FSM y la LCD.
- `fsm_state` avanzando en secuencia: `000 → 001 → 010 → 011 → 100 → 000`.
- `rs` en 0 durante los estados de configuración (`CONFIG_CMD1`, `CONFIG_CMD2`) y en 1 durante los estados de escritura de texto.
- `data` mostrando los comandos de inicialización (`0x38`, `0x06`, `0x0C`, `0x01`) seguidos de los códigos ASCII de "Bateria 1" (`0x42`, `0x61`, `0x74`...) en la primera línea, y "Bateria 2" en la segunda.
- `data_counter` incrementándose de `0x00` a `0x10` durante cada estado de escritura.

![Simulación GTKWave Parte 1](./figs/gtkwave_p1.png)

### Parte 2 — Texto dinámico

La simulación de la Parte 2 verifica el comportamiento del estado `WR_DIN_TEXT` y el sub-contador `sel_dinamic`. Con `temp1 = 4'd9` y `temp2 = 4'd15`, se observa:

- Al llegar a `WR_DIN_TEXT` (state = 5), `sel_dinamic` cicla de 0 a 5 indefinidamente.
- Para `temp1 = 9`: se envía `0x8B` (cursor línea 1), luego `0x30` ('0') y `0x39` ('9') → muestra "09".
- Para `temp2 = 15`: se envía `0xCB` (cursor línea 2), luego `0x31` ('1') y `0x35` ('5') → muestra "15".
- El ciclo se repite continuamente, actualizando los valores en tiempo real cada vez que cambian los switches.

![Simulación GTKWave Parte 2](./figs/gtkwave_p2.png)

---

<!-- (Incluir las de Digital si hicieron uso de esta herramienta, pero también deben incluir simulaciones realizadas usando un simulador HDL como por ejemplo Icarus Verilog + GTKwave) -->


## Implementación
La implementación se realizó sobre la tarjeta de desarrollo A-C4E6E10 con la FPGA Intel Cyclone IV EP4CE10E22C8, usando Quartus Prime Lite 23.1.

La pantalla LCD 16x2 se conectó directamente al header dedicado de la tarjeta, respetando la correspondencia del pin 1. La asignación de pines se realizó según la tabla impresa en la PCB de la tarjeta:

| Señal | Pin FPGA |
|---|---|
| `clk` | PIN_23 |
| `reset` | PIN_90 (botón K2, activo en bajo) |
| `rs` | PIN_85 |
| `rw` | PIN_99 |
| `enable` | PIN_100 |
| `data[0]` | PIN_101 |
| `data[1]` | PIN_103 |
| `data[2]` | PIN_104 |
| `data[3]` | PIN_105 |
| `data[4]` | PIN_110 |
| `data[5]` | PIN_111 |
| `data[6]` | PIN_112 |
| `data[7]` | PIN_113 |
| `temp1[0]` | PIN_64 |
| `temp1[1]` | PIN_60 |
| `temp1[2]` | PIN_59 |
| `temp1[3]` | PIN_58 |
| `temp2[0]` | PIN_68 |
| `temp2[1]` | PIN_67 |
| `temp2[2]` | PIN_66 |
| `temp2[3]` | PIN_65 |

Se configuró el pin `nCEO` (PIN_101) como I/O regular en `Assignments → Device → Device and Pin Options → Dual-Purpose Pins`, ya que por defecto funciona como pin de programación y no como dato.

### Parte 1 — Texto estático

![Implementación Parte 1](./figs/fpga_p1.jpg)

### Parte 2 — Texto dinámico

![Implementación Parte 2](./figs/fpga_p2.jpg)

---


## Conclusiones
- El uso de una FSM para controlar la secuencia de inicialización y escritura de la LCD permite gestionar de forma estructurada y clara el flujo de comandos y datos requeridos por el dispositivo, separando la lógica de control del datapath.

- El uso de `case(next_state)` en el bloque de datapath, en lugar de `case(fsm_state)`, es fundamental para sincronizar las salidas con las transiciones de estado y evitar latencia de un ciclo en las señales hacia la LCD.

- La señal `enable` conectada directamente a `clk_16ms` garantiza que la LCD capture los datos en el flanco correcto, respetando los tiempos mínimos de operación especificados en el datasheet.

- Para la implementación del texto dinámico, la estrategia de usar un estado en bucle con sub-estados internos (`sel_dinamic`) resulta más eficiente que agregar nuevos estados al flujo principal de la FSM, ya que permite actualizar los valores en tiempo real sin reinicializar la pantalla.

- La conversión de un valor numérico de 4 bits a su representación decimal en ASCII se realiza extrayendo decenas y unidades mediante división y módulo, y sumando `0x30` para obtener el código ASCII correspondiente.

---


## Referencias
- Intel. *Cyclone IV Device Handbook*. Intel Corporation, 2020.
- Hitachi. *HD44780U LCD Controller/Driver Datasheet*. Hitachi Semiconductor, 1998.
- Eslava, G. *Diapositivas de clase — Electrónica Digital I*. Universidad Nacional de Colombia.


