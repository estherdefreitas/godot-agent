# 🧠 Multi-Agent Survival Simulation (Godot 4)

Simulação emergente feita em **Godot 4** onde múltiplos agentes autônomos exploram o ambiente, buscam recursos, evitam perigo e competem por sobrevivência.

O sistema foi construído com foco em:

- Máquina de estados (FSM)
- Percepção baseada em área
- Memória espacial simples
- Sistema de energia
- Comportamento emergente
- Suporte a múltiplos agentes

---

# 🎮 Visão Geral

Cada agente:

- Possui energia própria
- Explora o mapa
- Procura cogumelos quando está com pouca energia
- Foge de zonas perigosas
- Aprende áreas já visitadas (evita repetir caminho)
- Pode morrer se a energia chegar a 0

Os agentes competem pelos mesmos recursos.

---

# 🏗 Estrutura do Projeto
```
scenes/
├── Game.tscn
├── Agent.tscn
├── Mushroom.tscn
├── Danger.tscn

scripts/
├── Game.gd
├── Agent.gd
├── Mushroom.gd
├── Danger.gd
```


---

# 🧩 Arquitetura

## 1️⃣ Agent (CharacterBody2D)

Estados possíveis:

```gdscript
enum State { EXPLORE, SEEK, FLEE }
```
### Comportamentos

#### EXPLORE

Movimento baseado em amostragem de direções

- Evita áreas perigosas
- Evita bordas do mapa
- Penaliza áreas já visitadas

#### SEEK

- Move até o cogumelo mais próximo
- Coleta quando próximo

#### FLEE

- Move na direção oposta ao perigo

## 2️⃣ Sistema de Energia

- Energia máxima configurável
- Gasto por pixel percorrido
- Dano contínuo em zonas de perigo
- Coleta de cogumelos restaura energia
- Ao chegar a 0 → agente morre

## 3️⃣ Memória Espacial

Cada agente mantém:
```gdscript
var visited_cells := {}
```
O mapa é dividido em células.

Cada vez que o agente visita uma célula:

- Incrementa contador
- Essa célula recebe penalidade futura
- Reduz repetição de trajetórias

## 4️⃣ Percepção

Usa:
```gdscript
Area2D + CollisionShape2D (CircleShape2D)
```

Detecta:

- Objetos do grupo "mushrooms"
- Objetos do grupo "dangers"

## 5️⃣ Sistema de Spawn

O Game.gd instancia:

- 2 agentes
- N cogumelos
- N zonas de perigo

Cogumelos:
- Não spawnam dentro de perigos
- Não spawnam colados nos agentes

## 🔋 UI

- Cada agente possui ProgressBar (EnergyBar) atualizada a cada frame
- Os cogumelos possuem opacidade diferente para quantidade de energia que contém

## ⚙️ Configurações Ajustáveis

No Agent.gd:
```gdscript
@export var max_speed
@export var perception_radius
@export var max_energy
@export var energy_threshold
@export var energy_cost_per_pixel
@export var danger_damage_per_sec
@export var memory_cell_size
```
No World.gd:
```gdscript
const AGENT_COUNT
const INITIAL_MUSHROOMS
const DANGER_COUNT
```

## 🧪 Comportamento Emergente Observado

- Agentes competem por recursos
- Um pode morrer antes do outro
- Um pode dominar regiões do mapa
- Mudanças pequenas em parâmetros alteram drasticamente o resultado
- Regiões perigosas moldam padrões de movimento

## 🚀 Como Executar

1. Abrir o projeto no Godot 4.x
2. Definir World.tscn como cena principal
3. Rodar

## 📌 Licença

Livre para uso educacional e experimentação.
