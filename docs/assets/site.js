const canvas = document.getElementById("robot-canvas");
const ctx = canvas.getContext("2d");

function resize() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.width = Math.floor(canvas.clientWidth * dpr);
  canvas.height = Math.floor(canvas.clientHeight * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function joint(x, y, r, color) {
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fillStyle = color;
  ctx.fill();
  ctx.lineWidth = 2;
  ctx.strokeStyle = "rgba(255,255,255,0.32)";
  ctx.stroke();
}

function segment(a, b, width, color) {
  ctx.beginPath();
  ctx.moveTo(a.x, a.y);
  ctx.lineTo(b.x, b.y);
  ctx.lineWidth = width;
  ctx.lineCap = "round";
  ctx.strokeStyle = color;
  ctx.stroke();
}

function draw(time) {
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  ctx.clearRect(0, 0, w, h);

  const t = time * 0.001;
  const base = { x: w * 0.67, y: h * 0.74 };
  const shoulder = { x: w * 0.61, y: h * 0.54 + Math.sin(t) * 10 };
  const elbow = { x: w * 0.72 + Math.cos(t * 0.8) * 18, y: h * 0.38 };
  const wrist = { x: w * 0.82, y: h * 0.28 + Math.sin(t * 1.2) * 8 };
  const tcp = { x: w * 0.88, y: h * 0.33 };

  const grid = 48;
  ctx.strokeStyle = "rgba(255,255,255,0.055)";
  ctx.lineWidth = 1;
  for (let x = 0; x < w; x += grid) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, h);
    ctx.stroke();
  }
  for (let y = 0; y < h; y += grid) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }

  segment(base, shoulder, 22, "rgba(118,217,207,0.90)");
  segment(shoulder, elbow, 18, "rgba(77,139,49,0.88)");
  segment(elbow, wrist, 14, "rgba(209,137,44,0.88)");
  segment(wrist, tcp, 9, "rgba(199,78,63,0.86)");
  [base, shoulder, elbow, wrist].forEach((p, i) => {
    const colors = ["#76d9cf", "#4d8b31", "#d1892c", "#c74e3f"];
    joint(p.x, p.y, 14 - i * 1.5, colors[i]);
  });

  ctx.beginPath();
  ctx.arc(tcp.x, tcp.y, 34 + Math.sin(t * 2) * 6, 0, Math.PI * 2);
  ctx.strokeStyle = "rgba(118,217,207,0.36)";
  ctx.lineWidth = 2;
  ctx.stroke();

  requestAnimationFrame(draw);
}

resize();
window.addEventListener("resize", resize);
requestAnimationFrame(draw);

