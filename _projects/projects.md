---
layout: default
title: Projects
permalink: /projects/
---

<h1 class="text-green">// PROJECTS</h1>
<p class="fg-dim" style="margin-bottom: 3rem;">
Tactical development logs and architectural research. These records document the transition from automated exploitation to custom engine design.
</p>

<div class="projects-grid">
{% assign sorted_projects = site.projects | where_exp: "item", "item.language != nil" | where_exp: "item", "item.project == nil" | sort: 'date' | reverse %}
{% for project in sorted_projects %}
<div class="project-card" style="border: 1px solid var(--border); padding: 1.5rem; margin-bottom: 2.5rem; background: #0a0a0a; position: relative; overflow: hidden;">
  
  <div style="position: absolute; top: 1rem; right: 1.5rem; font-family: var(--font-mono); font-size: 0.65rem;">
    <span style="color: {% if project.status == 'ACTIVE' %}var(--accent){% else %}#888{% endif %}; border: 1px solid {% if project.status == 'ACTIVE' %}var(--accent){% else %}#444{% endif %}; padding: 2px 8px;">
      [{{ project.status }}]
    </span>
  </div>

  <h2 style="margin: 0 0 1rem 0;"><a href="{{ project.url }}" style="color: var(--accent); border: none;">{{ project.title }}</a></h2>

  <div style="display: flex; gap: 1.5rem; font-family: var(--font-mono); font-size: 0.7rem; margin-bottom: 1.5rem; opacity: 0.6;">
    <span><span class="fg-dim">TIMELINE:</span> {{ project.period }}</span>
    <span><span class="fg-dim">LANG:</span> {{ project.language }}</span>
  </div>

  <div style="font-size: 0.9rem; line-height: 1.6; margin-bottom: 1.5rem;">
    {{ project.excerpt | strip_html | truncatewords: 30 }}
  </div>

  <div style="display: flex; flex-wrap: wrap; gap: 8px;">
    {% for tech in project.tech %}
    <span style="font-family: var(--font-mono); font-size: 0.6rem; background: rgba(255,255,255,0.05); border: 1px solid #333; padding: 2px 6px;">
      {{ tech }}
    </span>
    {% endfor %}
  </div>

  <div style="margin-top: 1.5rem; border-top: 1px solid #222; padding-top: 1rem; display: flex; justify-content: space-between; align-items: center;">
    <a href="{{ project.url }}" class="text-green" style="font-size: 0.8rem; font-family: var(--font-mono); border: none;">
      ACCESS_FULL_DOSSIER_AND_LOGS ->
    </a>

    {% if project.github %}
    <a href="{{ project.github }}" target="_blank" style="font-family: var(--font-mono); font-size: 0.75rem; color: var(--fg-dim); border: none; display: flex; align-items: center; gap: 5px;">
      <svg height="14" width="14" viewBox="0 0 16 16" fill="currentColor" style="opacity: 0.8;"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"></path></svg>
      SOURCE_CODE
    </a>
    {% endif %}
  </div>
  
</div>
{% endfor %}
</div>

<style>
hr {
    /* 1. Kill the 3D browser default */
    border: none !important;
    height: 1px !important;
    
    /* 2. Set the actual color (Dark Grey/Dim) */
    background-color: #222 !important; 
    
    /* 3. Spacing */
    margin: 3rem 0 !important;
    
    /* 4. Ensure no shadows are making it look 'thick' */
    box-shadow: none !important;
    outline: none !important;
}
</style>
