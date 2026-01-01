---
layout: default
title: CTF Writeups
permalink: /ctfs/
---

<h1 class="text-green">// Writeups</h1>
<p class="fg-dim" style="margin-bottom: 3rem;">
Detailed post-exploitation analysis and writeups for various platforms. These records document tactical execution across machines, challenges, and fortresses.
</p>

<div class="ctf-grid">
{% assign sorted_writeups = site.ctfs | where_exp: "item", "item.platform != nil" | sort: 'date' | reverse %}
{% for report in sorted_writeups %}
<div class="ctf-card" style="border: 1px solid var(--border); margin-bottom: 2.5rem; background: #0a0a0a; position: relative; overflow: hidden; display: flex; flex-direction: column;">
  
  <div style="width: 100%; height: 180px; overflow: hidden; border-bottom: 1px solid var(--border); background: #111;">
    <a href="{{ report.url }}" style="color: var(--accent); border: none;"><img src="{{ report.image }}" alt="{{ report.title }}" style="width: 100%; height: 100%; object-fit: cover; opacity: 0.6;"></a>
  </div>

  <div style="padding: 1.5rem;">
    <div style="position: absolute; top: 1rem; right: 1.5rem; font-family: var(--font-mono); font-size: 0.65rem;">
      <span style="
        background: rgba(0,0,0,0.8);
        border: 1px solid 
        {% if report.difficulty == 'Insane' %}#ffffff
        {% elsif report.difficulty == 'Hard' %}#ff4d4d
        {% elsif report.difficulty == 'Medium' %}#ffa500
        {% elsif report.difficulty == 'Easy' %}#00ff00
        {% elsif report.difficulty == 'Very Easy' %}#a333ff
        {% else %}var(--accent){% endif %};
        
        color: 
        {% if report.difficulty == 'Insane' %}#ffffff
        {% elsif report.difficulty == 'Hard' %}#ff4d4d
        {% elsif report.difficulty == 'Medium' %}#ffa500
        {% elsif report.difficulty == 'Easy' %}#00ff00
        {% elsif report.difficulty == 'Very Easy' %}#a333ff
        {% else %}var(--accent){% endif %};
        
        {% if report.difficulty == 'Insane' %}text-shadow: 0 0 5px rgba(255,255,255,0.6);{% endif %}
      ">
        [{{ report.difficulty | upcase }}]
      </span>
    </div>

    <h2 style="margin: 0 0 1rem 0;"><a href="{{ report.url }}" style="color: var(--accent); border: none;">{{ report.title }}</a></h2>

    <div style="display: flex; gap: 1.5rem; font-family: var(--font-mono); font-size: 0.7rem; margin-bottom: 1.5rem; opacity: 0.6;">
      <span><span class="fg-dim">PLATFORM:</span> {{ report.platform }}</span>
      <span><span class="fg-dim">TYPE:</span> {{ report.type }}</span>
    </div>

    <div style="font-size: 0.9rem; line-height: 1.6; margin-bottom: 1.5rem;">
      {{ report.excerpt | strip_html | truncatewords: 25 }}
    </div>

    <div style="display: flex; flex-wrap: wrap; gap: 8px;">
      {% for tag in report.tags %}
      <span style="font-family: var(--font-mono); font-size: 0.6rem; background: rgba(255,255,255,0.05); border: 1px solid #333; padding: 2px 6px;">
        #{{ tag }}
      </span>
      {% endfor %}
    </div>

    <div style="margin-top: 1.5rem; border-top: 1px solid #222; padding-top: 1rem;">
      <a href="{{ report.url }}" class="text-green" style="font-size: 0.8rem; font-family: var(--font-mono); border: none;">
        READ_FULL_REPORT ->
      </a>
    </div>
  </div>
</div>
{% endfor %}
</div>
