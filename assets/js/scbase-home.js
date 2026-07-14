(() => {
  const carousel = document.querySelector("[data-carousel]");
  if (!carousel) return;

  const viewport = carousel.querySelector(".hp-carousel-viewport");
  const track = carousel.querySelector("[data-carousel-track]");
  const slides = Array.from(track.children);
  const dotsWrap = carousel.querySelector("[data-carousel-dots]");
  const prev = carousel.querySelector("[data-carousel-prev]");
  const next = carousel.querySelector("[data-carousel-next]");
  const motionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
  let index = 0;
  let timer;
  let pages = [0];
  let dots = [];
  let offsets = [0];

  const update = () => {
    const offset = offsets[index] || 0;
    track.style.transform = `translateX(-${offset}px)`;
    dots.forEach((dot, dotIndex) => {
      const active = dotIndex === index;
      dot.classList.toggle("hp-carousel-dot-active", active);
      if (active) {
        dot.setAttribute("aria-current", "page");
      } else {
        dot.removeAttribute("aria-current");
      }
    });
  };

  const stop = () => {
    if (timer) window.clearInterval(timer);
  };

  const go = (nextIndex) => {
    index = (nextIndex + pages.length) % pages.length;
    update();
  };

  const start = () => {
    stop();
    if (motionQuery.matches || pages.length <= 1 || document.hidden) return;
    timer = window.setInterval(() => go(index + 1), 5200);
  };

  const measure = () => {
    const first = slides[0];
    if (!first) return;
    const slideWidth = first.getBoundingClientRect().width;
    const styles = window.getComputedStyle(track);
    const gap = Number.parseFloat(styles.columnGap || styles.gap || "0");
    const step = window.matchMedia("(max-width: 768px)").matches ? 1 : 2;
    const visible = Math.max(1, Math.floor((viewport.clientWidth + gap) / (slideWidth + gap)));
    const maxStart = Math.max(0, slides.length - visible);
    const maxOffset = Math.max(0, track.scrollWidth - viewport.clientWidth);
    pages = [];
    for (let startIndex = 0; startIndex < maxStart; startIndex += step) pages.push(startIndex);
    if (!pages.includes(maxStart)) pages.push(maxStart);
    if (pages.length === 0) pages = [0];
    offsets = pages.map((startIndex, pageIndex) => {
      if (pageIndex === pages.length - 1) return maxOffset;
      return Math.min(startIndex * (slideWidth + gap), maxOffset);
    });

    dotsWrap.innerHTML = "";
    dots = pages.map((_, pageIndex) => {
      const dot = document.createElement("button");
      dot.className = "hp-carousel-dot";
      dot.type = "button";
      dot.setAttribute("aria-label", `第 ${pageIndex + 1} 页`);
      dot.addEventListener("click", () => {
        index = pageIndex;
        update();
        start();
      });
      dotsWrap.appendChild(dot);
      return dot;
    });
    index = Math.min(index, pages.length - 1);
    update();
  };

  prev?.addEventListener("click", () => {
    go(index - 1);
    start();
  });
  next?.addEventListener("click", () => {
    go(index + 1);
    start();
  });
  carousel.addEventListener("mouseenter", stop);
  carousel.addEventListener("mouseleave", start);
  carousel.addEventListener("focusin", stop);
  carousel.addEventListener("focusout", start);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) stop(); else start();
  });
  motionQuery.addEventListener?.("change", start);
  window.addEventListener("resize", measure);
  measure();
  start();
})();
