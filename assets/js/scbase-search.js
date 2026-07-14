import Fuse from "fuse.js/basic";

const root = document.querySelector("[data-search]");

if (root) {
  const input = root.querySelector("#site-search");
  const form = root.querySelector(".sc-search-form");
  const status = root.querySelector(".sc-search-status");
  const resultsNode = root.querySelector(".sc-search-results");
  const tabs = [...root.querySelectorAll(".sc-search-tab")];
  let entries = [];
  let fuse;
  let activeFilter = "all";
  let debounceTimer;

  const createElement = (tag, className, text) => {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text) element.textContent = text;
    return element;
  };

  const renderResult = (item) => {
    const article = createElement("article", "sc-search-result");
    const link = createElement("a");
    link.href = item.url;
    if (/^https?:\/\//.test(item.url)) {
      link.target = "_blank";
      link.rel = "noopener noreferrer";
    }

    const meta = createElement("div", "sc-search-result-meta");
    meta.append(createElement("span", "", item.game));
    meta.append(createElement("span", "", item.type));
    if (item.date) {
      const time = createElement("time", "", item.date);
      time.dateTime = item.date;
      meta.append(time);
    }

    link.append(meta);
    link.append(createElement("h2", "sc-search-result-title", item.title));
    if (item.description) {
      link.append(createElement("p", "sc-search-result-description", item.description));
    }
    article.append(link);
    return article;
  };

  const filtered = (items) => {
    if (activeFilter === "all") return items;
    return items.filter((item) => item.kind === activeFilter);
  };

  const render = () => {
    const query = input.value.trim();
    let matches;

    if (query) {
      matches = fuse.search(query, { limit: 40 }).map((result) => result.item);
    } else {
      matches = [...entries]
        .sort((a, b) => (b.date || "").localeCompare(a.date || ""));
    }

    matches = filtered(matches).slice(0, query ? 20 : 8);
    resultsNode.replaceChildren(...matches.map(renderResult));

    if (query) {
      status.textContent = matches.length ? `找到 ${matches.length} 项结果` : "没有找到相关内容";
    } else if (activeFilter === "tool") {
      status.textContent = "常用工具";
    } else {
      status.textContent = "最近更新";
    }

    const url = new URL(window.location.href);
    if (query) url.searchParams.set("q", query);
    else url.searchParams.delete("q");
    window.history.replaceState({}, "", url);
  };

  const selectFilter = (filter) => {
    activeFilter = filter;
    tabs.forEach((tab) => {
      const active = tab.dataset.filter === filter;
      tab.classList.toggle("is-active", active);
      tab.setAttribute("aria-pressed", String(active));
    });
    render();
  };

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    render();
  });

  input.addEventListener("input", () => {
    window.clearTimeout(debounceTimer);
    debounceTimer = window.setTimeout(render, 120);
  });

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => selectFilter(tab.dataset.filter));
  });

  fetch(root.dataset.index)
    .then((response) => {
      if (!response.ok) throw new Error(`Search index returned ${response.status}`);
      return response.json();
    })
    .then((data) => {
      entries = data;
      fuse = new Fuse(entries, {
        threshold: 0.34,
        ignoreLocation: true,
        minMatchCharLength: 2,
        fieldNormWeight: 0.7,
        keys: [
          { name: "title", weight: 0.45 },
          { name: "tags", weight: 0.18 },
          { name: "keywords", weight: 0.16 },
          { name: "description", weight: 0.12 },
          { name: "game", weight: 0.06 },
          { name: "type", weight: 0.03 },
        ],
      });

      input.value = new URL(window.location.href).searchParams.get("q") || "";
      render();
    })
    .catch(() => {
      status.textContent = "搜索暂时不可用";
      resultsNode.replaceChildren(createElement("p", "sc-search-message", "搜索索引载入失败，请稍后重试。"));
    });
}
