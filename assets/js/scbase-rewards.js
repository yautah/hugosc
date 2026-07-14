document.querySelectorAll("[data-rewards]").forEach((root) => {
  root.querySelectorAll("[data-copy-code]").forEach((button) => {
    button.addEventListener("click", async () => {
      const original = button.textContent;
      try {
        await navigator.clipboard.writeText(button.dataset.copyCode);
        button.textContent = "已复制";
      } catch {
        button.textContent = "复制失败";
      }
      window.setTimeout(() => {
        button.textContent = original;
      }, 1600);
    });
  });
});
