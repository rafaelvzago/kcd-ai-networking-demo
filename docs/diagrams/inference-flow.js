const byId = id => document.getElementById(id);
const root = byId("flowstory-root");
const status = byId("fs-status");

root.innerHTML = `
  <button class="fs-theme-toggle" id="fs-theme" type="button" aria-label="Alternar tema" title="Alternar tema">☾</button>
  <button id="fs-panel-toggle" type="button" aria-label="Ocultar painel" aria-expanded="true" title="Ocultar painel">›</button>
  <div class="fs-brand" id="fs-brand"></div><div class="fs-title" id="fs-title"></div>
  <div class="fs-panel" id="fs-panel">
    <div class="fs-flow-bar">
      <select id="fs-flow-select" aria-label="Fluxo"></select>
      <button class="fs-start" id="fs-play" type="button">▶ Iniciar</button>
      <select id="fs-speed" aria-label="Velocidade de reprodução"><option value="1">1×</option><option value="2" selected>2×</option><option value="4">4×</option></select>
      <button id="fs-loop" type="button">↻ Repetir</button>
      <button class="fs-reset" id="fs-reset" type="button">Reiniciar</button>
    </div>
    <div class="fs-steps" id="fs-steps"><div class="fs-steps-title">Etapas do fluxo <span>· clique para avançar</span></div><div id="fs-steps-container"></div></div>
  </div>
  <div id="fs-highlight-box" style="display:none;position:fixed;pointer-events:none"></div>
  <div id="fs-overlay" style="display:none;position:fixed;inset:0;background:#0009"><div id="fs-overlay-card" role="dialog" aria-modal="true" aria-labelledby="fs-overlay-title" aria-describedby="fs-overlay-desc"><button id="fs-overlay-close" type="button" aria-label="Fechar detalhes">✕</button><div id="fs-overlay-accent"></div><h2 id="fs-overlay-title"></h2><p id="fs-overlay-desc"></p><div id="fs-overlay-details"></div><button id="fs-overlay-resume" type="button">▶ Retomar fluxo</button></div></div>
  <div class="fs-legend" id="fs-legend"></div><canvas id="fs-canvas" role="img" aria-label="Diagrama animado do fluxo" tabindex="-1"></canvas>`;

let viz;
const narrow = matchMedia("(max-width: 900px)");
const panel = byId("fs-panel");
const toggle = byId("fs-panel-toggle");
function setSidebar(collapsed) {
  document.body.classList.toggle("sidebar-collapsed", collapsed);
  panel.inert = collapsed;
  toggle.textContent = collapsed ? "‹" : "›";
  toggle.setAttribute("aria-label", collapsed ? "Mostrar painel" : "Ocultar painel");
  toggle.setAttribute("title", collapsed ? "Mostrar painel" : "Ocultar painel");
  toggle.setAttribute("aria-expanded", String(!collapsed));
  if (viz) {
    viz._engine.panelWidth = collapsed || narrow.matches ? 0 : 380;
    viz._engine.resize();
  }
}
setSidebar(narrow.matches);
toggle.addEventListener("click", () => setSidebar(!document.body.classList.contains("sidebar-collapsed")));
narrow.addEventListener("change", event => setSidebar(event.matches));

try {
  const flowKey = document.body.dataset.flow;
  const response = await fetch("../architecture/diagram.json");
  if (!response.ok) throw new Error(`diagram.json: HTTP ${response.status}`);
  const diagram = await response.json();
  const flow = diagram.flows?.[flowKey];
  if (!flow?.steps?.length) throw new Error(`Fluxo não encontrado: ${flowKey}`);
  diagram.flows = { [flowKey]: flow };
  diagram.flowOrder = [flowKey];
  diagram.defaultFlow = flowKey;
  const { FlowStory } = await import("https://noyitz.github.io/flowstory/src/index.js");

  viz = new FlowStory(byId("fs-canvas"), {
    stepsContainer: byId("fs-steps-container"),
    overlay: byId("fs-overlay"), overlayCard: byId("fs-overlay-card"),
    overlayTitle: byId("fs-overlay-title"), overlayDesc: byId("fs-overlay-desc"),
    overlayDetails: byId("fs-overlay-details"), overlayAccent: byId("fs-overlay-accent"),
    overlayClose: byId("fs-overlay-close"), overlayResume: byId("fs-overlay-resume"),
    highlightBox: byId("fs-highlight-box"), brand: byId("fs-brand"), title: byId("fs-title"),
    legend: byId("fs-legend"), flowSelect: byId("fs-flow-select"), playBtn: byId("fs-play"),
    loopBtn: byId("fs-loop"), resetBtn: byId("fs-reset"), themeBtn: byId("fs-theme")
  });
  viz._engine.panelWidth = narrow.matches ? 0 : 380;
  await viz.load(diagram);
  setSidebar(narrow.matches);
  const steps = byId("fs-steps-container");
  const enableStepKeys = () => steps.querySelectorAll(".fs-step").forEach(step => {
    step.tabIndex = 0;
    step.setAttribute("role", "button");
  });
  new MutationObserver(enableStepKeys).observe(steps, { childList: true });
  enableStepKeys();
  steps.addEventListener("keydown", event => {
    if ((event.key === "Enter" || event.key === " ") && event.target.classList.contains("fs-step")) {
      event.preventDefault();
      event.target.click();
    }
  });

  const overlay = byId("fs-overlay");
  const card = byId("fs-overlay-card");
  const canvas = byId("fs-canvas");
  new MutationObserver(() => {
    if (overlay.style.display === "block") byId("fs-overlay-close").focus();
    else canvas.focus();
  }).observe(overlay, { attributes: true, attributeFilter: ["style"] });
  document.addEventListener("keydown", event => {
    if (overlay.style.display !== "block") return;
    if (event.key === "Escape") {
      event.preventDefault();
      viz.closeOverlay();
    } else if (event.key === "Tab") {
      const focusable = [...card.querySelectorAll("button:not([disabled]),a[href]")];
      const first = focusable[0], last = focusable.at(-1);
      if (event.shiftKey && (document.activeElement === first || !card.contains(document.activeElement))) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && (document.activeElement === last || !card.contains(document.activeElement))) {
        event.preventDefault();
        first.focus();
      }
    }
  });
  byId("fs-speed").addEventListener("change", event => viz.setSpeed(Number(event.target.value)));
  viz.setSpeed(2);
  viz.state.loopMode = true;
  byId("fs-loop").textContent = "↻ Repetir: sim";
  status.hidden = true;
  viz.play();
} catch (error) {
  console.error("Erro ao carregar FlowStory:", error);
  root.hidden = true;
  status.textContent = `Não foi possível carregar o diagrama: ${error.message}`;
  status.setAttribute("role", "alert");
}
