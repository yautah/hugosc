from __future__ import annotations

import html
import re
from dataclasses import dataclass


IMAGE_RE = re.compile(r"!\[(?P<alt>[^\]]*)\]\((?P<src>[^)\s]+)(?:\s+\"[^\"]*\")?\)")
OBSIDIAN_IMAGE_RE = re.compile(r"!\[\[(?P<target>[^\]]+)\]\]")
LINK_RE = re.compile(r"\[(?P<text>[^\]]+)\]\((?P<href>[^)\s]+)(?:\s+\"[^\"]*\")?\)")
BOLD_RE = re.compile(r"\*\*(?P<text>.+?)\*\*")
CODE_RE = re.compile(r"`(?P<text>[^`]+)`")
ORDERED_ITEM_RE = re.compile(r"^\d+\.\s+")
TABLE_DELIMITER_CELL_RE = re.compile(r"^:?-{3,}:?$")


@dataclass(frozen=True)
class HtmlTemplate:
    name: str
    base: dict[str, str]
    styles: dict[str, dict[str, str]]
    unwrap_links: bool
    image_style: str


def markdown_to_html(
    markdown_text: str,
    *,
    unwrap_links: bool = False,
    image_style: str = "",
    template: str = "default",
) -> str:
    html_template = get_template(template, unwrap_links=unwrap_links, image_style=image_style)
    lines = markdown_text.splitlines()
    blocks: list[str] = []
    paragraph: list[str] = []
    list_items: list[str] = []
    ordered_items: list[str] = []
    quote_lines: list[str] = []
    code_lines: list[str] = []
    in_code_block = False

    def flush_paragraph() -> None:
        if paragraph:
            text = " ".join(paragraph)
            image_block = _image_block(text, html_template)
            if image_block:
                blocks.append(image_block)
            else:
                blocks.append(f"<p{_attr(html_template, 'p')}>{_inline(text, html_template)}</p>")
            paragraph.clear()

    def flush_list() -> None:
        if list_items:
            items = "".join(
                f"<li{_attr(html_template, 'listitem')}>{_inline(item, html_template)}</li>" for item in list_items
            )
            blocks.append(f"<ul{_attr(html_template, 'ul')}>{items}</ul>")
            list_items.clear()

    def flush_ordered_list() -> None:
        if ordered_items:
            items = "".join(
                f"<li{_attr(html_template, 'listitem')}>{_inline(item, html_template)}</li>" for item in ordered_items
            )
            blocks.append(f"<ol{_attr(html_template, 'ol')}>{items}</ol>")
            ordered_items.clear()

    def flush_quote() -> None:
        if quote_lines:
            text = " ".join(quote_lines)
            if html_template.name == "redream-obsidian-blue":
                inner = f"<p{_attr(html_template, 'blockquote_p')}>{_inline(text, html_template)}</p>"
                blocks.append(f"<blockquote{_attr(html_template, 'blockquote')}>{inner}</blockquote>")
            else:
                blocks.append(f"<blockquote><p>{_inline(text, html_template)}</p></blockquote>")
            quote_lines.clear()

    def flush_code_block() -> None:
        if code_lines:
            code = html.escape("\n".join(code_lines), quote=False)
            if html_template.name == "redream-obsidian-blue":
                code = code.replace(" ", "&nbsp;").replace("\n", "<br/>")
                blocks.append(
                    f'<pre class="hljs code__pre"{_attr(html_template, "code_pre")}><code class="prettyprint language-plaintext"{_attr(html_template, "code")}>{code}</code></pre>'
                )
            else:
                blocks.append(f"<pre><code>{code}</code></pre>")
            code_lines.clear()

    def flush_all() -> None:
        flush_paragraph()
        flush_list()
        flush_ordered_list()
        flush_quote()

    skip_until = -1
    for line_index, line in enumerate(lines):
        if line_index <= skip_until:
            continue
        stripped = line.strip()
        if stripped.startswith("```"):
            if in_code_block:
                flush_code_block()
                in_code_block = False
            else:
                flush_all()
                in_code_block = True
            continue
        if in_code_block:
            code_lines.append(line)
            continue
        if not stripped:
            flush_all()
            continue
        if line_index + 1 < len(lines) and _is_table_delimiter(lines[line_index + 1]):
            header = _split_table_row(stripped)
            if header:
                flush_all()
                rows: list[list[str]] = []
                cursor = line_index + 2
                while cursor < len(lines):
                    row_line = lines[cursor].strip()
                    if not row_line or "|" not in row_line:
                        break
                    rows.append(_split_table_row(row_line))
                    cursor += 1
                blocks.append(_render_table(header, rows, html_template))
                skip_until = cursor - 1
                continue
        if stripped in {"---", "***", "___"}:
            flush_all()
            blocks.append(f"<hr{_attr(html_template, 'hr')}>")
            continue
        if stripped.startswith("#"):
            flush_all()
            level = min(len(stripped) - len(stripped.lstrip("#")), 6)
            text = stripped[level:].strip()
            style_key = f"h{min(level, 4)}"
            blocks.append(f"<h{level}{_attr(html_template, style_key)}>{_inline(text, html_template)}</h{level}>")
            continue
        if stripped.startswith(">"):
            flush_paragraph()
            flush_list()
            flush_ordered_list()
            quote_lines.append(stripped.lstrip(">").strip())
            continue
        if stripped.startswith(("- ", "* ")):
            flush_paragraph()
            flush_quote()
            flush_ordered_list()
            list_items.append(stripped[2:].strip())
            continue
        if ORDERED_ITEM_RE.match(stripped):
            flush_paragraph()
            flush_quote()
            flush_list()
            ordered_items.append(ORDERED_ITEM_RE.sub("", stripped, count=1).strip())
            continue
        paragraph.append(stripped)

    if in_code_block:
        flush_code_block()
    flush_all()
    return "\n".join(blocks) + "\n"


def _inline(text: str, template: HtmlTemplate) -> str:
    escaped = html.escape(text, quote=True)

    def image(match: re.Match[str]) -> str:
        alt = html.escape(match.group("alt"), quote=True)
        src = html.escape(match.group("src"), quote=True)
        style = _attr(template, "image") if template.name == "redream-obsidian-blue" else _raw_style_attr(template.image_style)
        return f'<img src="{src}" alt="{alt}"{style}>'

    def obsidian_image(match: re.Match[str]) -> str:
        src, alt = _split_obsidian_target(match.group("target"))
        escaped_alt = html.escape(alt, quote=True)
        escaped_src = html.escape(src, quote=True)
        style = _attr(template, "image") if template.name == "redream-obsidian-blue" else _raw_style_attr(template.image_style)
        return f'<img src="{escaped_src}" alt="{escaped_alt}"{style}>'

    def link(match: re.Match[str]) -> str:
        label = html.escape(match.group("text"), quote=True)
        href = html.escape(match.group("href"), quote=True)
        if template.unwrap_links:
            return label
        if href.startswith("https://mp.weixin.qq.com"):
            return f'<a href="{href}"{_attr(template, "wx_link")}>{label}</a>'
        return f'<span{_attr(template, "link")}>{label}</span>' if template.name == "redream-obsidian-blue" else f'<a href="{href}">{label}</a>'

    def bold(match: re.Match[str]) -> str:
        return f'<strong{_attr(template, "strong")}>{match.group("text")}</strong>'

    def code(match: re.Match[str]) -> str:
        return f'<code{_attr(template, "codespan")}>{match.group("text")}</code>'

    escaped = IMAGE_RE.sub(image, escaped)
    escaped = OBSIDIAN_IMAGE_RE.sub(obsidian_image, escaped)
    escaped = LINK_RE.sub(link, escaped)
    escaped = BOLD_RE.sub(bold, escaped)
    escaped = CODE_RE.sub(code, escaped)
    return escaped


def get_template(name: str, *, unwrap_links: bool, image_style: str) -> HtmlTemplate:
    if name == "redream-obsidian-blue":
        base_font = "-apple-system-font,BlinkMacSystemFont, Helvetica Neue, PingFang SC, Hiragino Sans GB, Microsoft YaHei UI, Microsoft YaHei, Arial, sans-serif"
        accent = "rgba(15, 76, 129, 1)"
        text = "#3f3f3f"
        base = {"text-align": "left", "line-height": "1.75", "font-family": base_font, "font-size": "16px"}
        styles = {
            "h1": {**base, "font-size": "18.24px", "text-align": "center", "font-weight": "bold", "display": "table", "margin": "2em auto 1em", "padding": "0 1em", "border-bottom": f"2px solid {accent}", "color": text},
            "h2": {**base, "font-size": "17.6px", "text-align": "center", "font-weight": "bold", "display": "table", "margin": "4em auto 2em", "padding": "0 0.2em", "background": accent, "color": "#fff"},
            "h3": {**base, "font-weight": "bold", "font-size": "16px", "margin": "2em 8px 0.75em 0", "line-height": "1.2", "padding-left": "8px", "border-left": f"3px solid {accent}", "color": text},
            "h4": {**base, "font-weight": "bold", "font-size": "16px", "margin": "2em 8px 0.5em", "color": accent},
            "p": {**base, "margin": "1.5em 8px", "letter-spacing": "0.1em", "color": text},
            "blockquote": {**base, "font-style": "normal", "border-left": "none", "padding": "1em", "border-radius": "8px", "color": "rgba(0,0,0,0.5)", "background": "#f7f7f7", "margin": "2em 8px"},
            "blockquote_p": {**base, "letter-spacing": "0.1em", "color": "rgb(80, 80, 80)", "font-size": "16px", "display": "block"},
            "figure": {**base, "margin": "1.5em 8px", "color": text},
            "image": {"border-radius": "4px", "display": "block", "margin": "0.1em auto 0.5em", "width": "100% !important", "height": "auto"},
            "figcaption": {**base, "text-align": "center", "color": "#888", "font-size": "0.8em"},
            "hr": {"border-style": "solid", "border-width": "1px 0 0", "border-color": "rgba(0,0,0,0.1)", "transform-origin": "0 0", "transform": "scale(1, 0.5)"},
            "ul": {**base, "margin": "1.5em 8px", "padding-left": "1.5em", "list-style-type": "disc", "color": text},
            "ol": {**base, "margin": "1.5em 8px", "padding-left": "1.5em", "color": text},
            "listitem": {**base, "display": "list-item", "margin": "0.4em 0", "color": text},
            "table": {**base, "width": "100%", "table-layout": "fixed", "border-collapse": "collapse", "margin": "1.5em 0", "font-size": "14px", "color": text},
            "th": {**base, "padding": "8px 6px", "border": "1px solid #d9d9d9", "background": "#f3f6f8", "font-size": "14px", "font-weight": "bold", "text-align": "left", "vertical-align": "top", "word-break": "break-word", "color": text},
            "td": {**base, "padding": "8px 6px", "border": "1px solid #d9d9d9", "font-size": "14px", "text-align": "left", "vertical-align": "top", "word-break": "break-word", "color": text},
            "code_pre": {"font-size": "14px", "overflow-x": "auto", "border-radius": "8px", "padding": "1em", "line-height": "1.5", "margin": "10px 8px", "background": "#282c34", "color": "#abb2bf"},
            "code": {"margin": "0", "white-space": "nowrap", "font-family": "Menlo, Operator Mono, Consolas, Monaco, monospace"},
            "codespan": {**base, "font-size": "90%", "white-space": "pre", "color": "#d14", "background": "rgba(27,31,35,.05)", "padding": "3px 5px", "border-radius": "4px"},
            "strong": {**base, "color": accent, "font-weight": "bold"},
            "link": {**base, "color": "#576b95"},
            "wx_link": {**base, "color": "#576b95", "text-decoration": "none"},
        }
        return HtmlTemplate(name=name, base=base, styles=styles, unwrap_links=False, image_style="")
    return HtmlTemplate(name="default", base={}, styles={}, unwrap_links=unwrap_links, image_style=image_style)


def _image_block(text: str, template: HtmlTemplate) -> str | None:
    if template.name != "redream-obsidian-blue":
        return None
    markdown_match = IMAGE_RE.fullmatch(text.strip())
    obsidian_match = OBSIDIAN_IMAGE_RE.fullmatch(text.strip())
    if markdown_match:
        src = markdown_match.group("src").strip()
        alt = markdown_match.group("alt").strip()
    elif obsidian_match:
        src, alt = _split_obsidian_target(obsidian_match.group("target"))
    else:
        return None
    escaped_src = html.escape(src, quote=True)
    escaped_alt = html.escape(alt, quote=True)
    caption = f"<figcaption{_attr(template, 'figcaption')}>{escaped_alt}</figcaption>" if escaped_alt else ""
    return f'<figure{_attr(template, "figure")}><img referrerpolicy="same-origin"{_attr(template, "image")} src="{escaped_src}" title="{escaped_alt}" alt="{escaped_alt}"/>{caption}</figure>'


def _split_table_row(line: str) -> list[str]:
    row = line.strip()
    if row.startswith("|"):
        row = row[1:]
    if row.endswith("|") and not row.endswith(r"\|"):
        row = row[:-1]
    return [cell.strip().replace(r"\|", "|") for cell in re.split(r"(?<!\\)\|", row)]


def _is_table_delimiter(line: str) -> bool:
    cells = _split_table_row(line)
    return bool(cells) and all(TABLE_DELIMITER_CELL_RE.fullmatch(cell) for cell in cells)


def _render_table(header: list[str], rows: list[list[str]], template: HtmlTemplate) -> str:
    column_count = len(header)

    def cells(values: list[str], tag: str) -> str:
        normalized = (values + [""] * column_count)[:column_count]
        return "".join(f"<{tag}{_attr(template, tag)}>{_inline(value, template)}</{tag}>" for value in normalized)

    head = f"<thead><tr>{cells(header, 'th')}</tr></thead>"
    body = "".join(f"<tr>{cells(row, 'td')}</tr>" for row in rows)
    return f"<table{_attr(template, 'table')}>{head}<tbody>{body}</tbody></table>"


def _style_attr(template: HtmlTemplate, key: str) -> str:
    styles = template.styles.get(key)
    if not styles:
        return ""
    return 'style="' + ";".join(f"{name}:{value}" for name, value in styles.items()) + '"'


def _attr(template: HtmlTemplate, key: str) -> str:
    style = _style_attr(template, key)
    return f" {style}" if style else ""


def _raw_style_attr(style: str) -> str:
    return f' style="{html.escape(style, quote=True)}"' if style else ""


def _split_obsidian_target(target: str) -> tuple[str, str]:
    parts = target.split("|", 1)
    src = parts[0].strip()
    alt = parts[1].strip() if len(parts) > 1 else src.rsplit("/", 1)[-1].rsplit(".", 1)[0]
    return src, alt
