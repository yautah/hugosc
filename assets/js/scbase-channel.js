(() => {
  const track = document.querySelector(".sc-section-guides .sc-guide-grid");
  const dotsWrap = document.querySelector("[data-guide-dots]");

  if (!track || !dotsWrap) return;

  const cards = Array.from(track.querySelectorAll(".sc-guide-card"));
  if (cards.length < 2) return;
  const mobile = window.matchMedia("(max-width: 768px)");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const autoDelay = 5000;
  let positions = [];
  let dots = [];
  let activePage = 0;
  let autoTimer;
  let resizeTimer;
  let scrollFallback;

  const setActivePage = (index) => {
    activePage = index;
    dots.forEach((dot, dotIndex) => {
      const active = dotIndex === activePage;
      dot.classList.toggle("is-active", active);
      dot.setAttribute("aria-current", active ? "true" : "false");
    });
  };

  const goToPage = (index, smooth = true) => {
    if (!positions.length) return;
    const targetPage = (index + positions.length) % positions.length;
    const targetPosition = positions[targetPage];
    window.clearTimeout(scrollFallback);
    track.scrollTo({
      left: targetPosition,
      behavior: smooth && !reducedMotion.matches ? "smooth" : "auto",
    });
    setActivePage(targetPage);
    scrollFallback = window.setTimeout(() => {
      if (Math.abs(track.scrollLeft - targetPosition) > 1) {
        track.scrollLeft = targetPosition;
        updateActivePage();
      }
    }, 500);
  };

  const stopAuto = () => {
    window.clearInterval(autoTimer);
  };

  const startAuto = () => {
    stopAuto();
    if (!mobile.matches || reducedMotion.matches || positions.length < 2) return;
    autoTimer = window.setInterval(() => goToPage(activePage + 1), autoDelay);
  };

  const updateActivePage = () => {
    if (!positions.length) return;
    let closestPage = 0;
    let closestDistance = Infinity;
    positions.forEach((position, index) => {
      const distance = Math.abs(position - track.scrollLeft);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestPage = index;
      }
    });
    setActivePage(closestPage);
  };

  const buildPages = () => {
    stopAuto();
    dotsWrap.replaceChildren();
    dots = [];
    positions = [];

    if (!mobile.matches) return;

    const visibleCards = 2;
    const lastStart = Math.max(0, cards.length - visibleCards);
    const starts = [];

    for (let index = 0; index < lastStart; index += visibleCards) {
      starts.push(index);
    }
    if (!starts.includes(lastStart)) starts.push(lastStart);

    const maxScroll = track.scrollWidth - track.clientWidth;
    positions = starts.map((cardIndex) => Math.min(
      cards[cardIndex].offsetLeft - track.offsetLeft,
      maxScroll,
    ));

    positions.forEach((position, index) => {
      const dot = document.createElement("button");
      dot.type = "button";
      dot.className = "sc-guide-dot";
      dot.setAttribute("aria-label", `查看第 ${index + 1} 页长期攻略`);
      dot.addEventListener("click", () => {
        goToPage(index);
        startAuto();
      });
      dotsWrap.appendChild(dot);
      dots.push(dot);
    });

    const nearestPage = positions.reduce((nearest, position, index) => (
      Math.abs(position - track.scrollLeft) < Math.abs(positions[nearest] - track.scrollLeft)
        ? index
        : nearest
    ), 0);
    goToPage(nearestPage, false);
    startAuto();
  };

  track.addEventListener("scroll", updateActivePage, { passive: true });
  track.addEventListener("pointerdown", stopAuto, { passive: true });
  track.addEventListener("pointerup", startAuto, { passive: true });
  track.addEventListener("pointercancel", startAuto, { passive: true });
  track.addEventListener("focusin", stopAuto);
  track.addEventListener("focusout", startAuto);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) stopAuto();
    else startAuto();
  });
  window.addEventListener("resize", () => {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(buildPages, 120);
  });

  buildPages();
})();
