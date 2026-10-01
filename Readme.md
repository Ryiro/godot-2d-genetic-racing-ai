

https://github.com/user-attachments/assets/533cdba7-8b3e-4eb1-acf9-e79b40e02aef



# 🏎️ 2D Autonomous Genetic Racing AI (Godot 4)

An evolutionary self-driving racing simulation built in Godot 4. A population of neural-network-controlled vehicles learns to navigate a custom circuit from scratch, discovering optimal racing lines, apex clipping, and threshold cornering without any scripted waypoints.

<!-- Paste your uploaded video link right here -->

---

## ⚡ Highlights

- **Physical World Record:** Achieved an optimized lap time of **9.43s** (hitting the kinematic ceiling of the 380 px/s engine limit).
- **Feedforward Neural Architecture:** 7 inputs (5 distance raycasts, speed ratio, tangent angle) $\rightarrow$ 6 hidden nodes $\rightarrow$ 2 outputs (steering & throttle/brake).
- **Elitist Evolution:** Preserves top champions directly, crosses over high-performing genes, and applies micro-mutations to explore faster trajectories.
- **Dynamic Telemetry HUD:** Real-time generation counters, round timers, best lap indicators, and variable simulation speed toggles (1x, 2x, 5x, 10x).

---

## 🎮 Controls

| Key | Action |
| :--- | :--- |
| **Space** | Cycle simulation speed (1x $\rightarrow$ 2x $\rightarrow$ 5x $\rightarrow$ 10x) |
| **Esc** | Exit simulation |

---

## 🛠️ Getting Started

1. Clone this repository: https://github.com/Ryiro/godot-2d-genetic-racing-ai
2.  Open **Godot Engine 4.x**.
3. Click **Import** and select the `project.godot` file.
4. Press **F5** to run the simulation.
