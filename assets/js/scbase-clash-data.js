(() => {
  const normalize = (value) => String(value || "").trim().toLocaleLowerCase("zh-CN");

  document.querySelectorAll("[data-filter-root]").forEach((root) => {
    const items = [...root.querySelectorAll("[data-filter-item]")];
    const search = root.querySelector("[data-filter-search]");
    const count = root.querySelector("[data-result-count]");
    const empty = root.querySelector("[data-filter-empty]");
    const state = {};

    const apply = () => {
      const query = normalize(search?.value);
      let visible = 0;

      items.forEach((item) => {
        const matchesSearch = !query || normalize(item.dataset.search).includes(query);
        const matchesGroups = Object.entries(state).every(([key, value]) => {
          return !value || value === "all" || item.dataset[key] === value;
        });
        const matches = matchesSearch && matchesGroups;
        item.hidden = !matches;
        if (matches) visible += 1;
      });

      if (count) count.textContent = visible;
      if (empty) empty.hidden = visible !== 0;
    };

    search?.addEventListener("input", apply);

    root.querySelectorAll("[data-filter-group]").forEach((group) => {
      const key = group.dataset.filterGroup;
      group.addEventListener("click", (event) => {
        const button = event.target.closest("[data-filter-value]");
        if (!button) return;
        group.querySelectorAll("[data-filter-value]").forEach((item) => item.classList.remove("is-active"));
        button.classList.add("is-active");
        state[key] = button.dataset.filterValue;
        const select = root.querySelector(`[data-filter-select="${key}"]`);
        if (select) select.value = state[key];
        apply();
      });
    });

    root.querySelectorAll("[data-filter-select]").forEach((select) => {
      const key = select.dataset.filterSelect;
      select.addEventListener("change", () => {
        state[key] = select.value;
        const group = root.querySelector(`[data-filter-group="${key}"]`);
        if (group) {
          group.querySelectorAll("[data-filter-value]").forEach((button) => {
            button.classList.toggle("is-active", button.dataset.filterValue === state[key]);
          });
        }
        apply();
      });
    });
  });

  document.querySelectorAll("[data-copy-deck]").forEach((button) => {
    button.addEventListener("click", async () => {
      const deck = document.querySelector(".sc-deck-cards[data-deck-name]");
      if (!deck) return;
      const cards = [...deck.querySelectorAll("[data-card-name]")].map((item) => item.dataset.cardName);
      const text = `${deck.dataset.deckName}：${cards.join("、")}`;

      try {
        await navigator.clipboard.writeText(text);
        const original = button.textContent;
        button.textContent = "已复制";
        setTimeout(() => { button.textContent = original; }, 1600);
      } catch {
        window.prompt("复制卡组清单", text);
      }
    });
  });
})();
