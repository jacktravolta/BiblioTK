module ApplicationHelper
  def corporate_paginator(current_page, total_pages, total_count, per_page, param_name: :page, path: nil)
    return "" if total_pages <= 1
    path ||= request.path
    # conserva otros params
    base_params = request.query_parameters.except(param_name.to_s)

    html = %Q{<div class="d-flex justify-content-between align-items-center mt-4 p-3 bg-white border rounded-3" style="border-radius:12px!important;">
      <div class="small text-muted">Página #{current_page} de #{total_pages} • #{total_count} registros • #{per_page} por página</div>
      <div class="d-flex gap-1">}

    # Prev
    if current_page > 1
      prev_params = base_params.merge(param_name => current_page - 1)
      html += %Q{<a href="#{path}?#{prev_params.to_query}" class="btn btn-sm" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;">← Anterior</a>}
    else
      html += %Q{<span class="btn btn-sm disabled" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;opacity:0.5;">← Anterior</span>}
    end

    # Números (ventana de 5)
    start_p = [current_page - 2, 1].max
    end_p = [start_p + 4, total_pages].min
    start_p = [end_p - 4, 1].max

    (start_p..end_p).each do |p|
      if p == current_page
        html += %Q{<span class="btn btn-sm" style="background:#0f172a;color:white;border-radius:8px;min-width:36px;">#{p}</span>}
      else
        pp = base_params.merge(param_name => p)
        html += %Q{<a href="#{path}?#{pp.to_query}" class="btn btn-sm" style="background:white;border:1px solid #e2e8f0;border-radius:8px;min-width:36px;">#{p}</a>}
      end
    end

    # Next
    if current_page < total_pages
      next_params = base_params.merge(param_name => current_page + 1)
      html += %Q{<a href="#{path}?#{next_params.to_query}" class="btn btn-sm" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;">Siguiente →</a>}
    else
      html += %Q{<span class="btn btn-sm disabled" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;opacity:0.5;">Siguiente →</span>}
    end

    html += "</div></div>"
    html.html_safe
  end
end
