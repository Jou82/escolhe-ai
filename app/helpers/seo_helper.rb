# app/helpers/seo_helper.rb
module SeoHelper
  # Gera o título completo da página
  # Uso: <%= seo_title("Comparar Notebooks") %>
  def seo_title(page_title = nil)
    base_title = "Escolhe Aí | Ferramenta Inteligente para Tomar Decisões - Compare e Escolha"

    if page_title.present?
      "#{page_title} | #{base_title}"
    else
      base_title
    end
  end

  # Gera a meta description da página
  # Uso: <%= seo_description("Descrição personalizada para esta página") %>
  def seo_description(description = nil)
    if description.present?
      description
    else
      "Escolhe Aí - ferramenta inteligente para tomar decisões. Compare opções lado a lado, analise critérios personalizados e descubra a melhor escolha. Busca otimizada com 3 consultas/dia. Experimente grátis!"
    end
  end

  # Gera título para Open Graph
  def og_title(title = nil)
    if title.present?
      title
    else
      "Escolhe Aí | Ferramenta Inteligente para Tomar Decisões"
    end
  end

  # Gera descrição para Open Graph
  def og_description(description = nil)
    if description.present?
      description
    else
      "Ferramenta gratuita que ajuda você a comparar opções e tomar decisões mais inteligentes. Análise personalizada e resultados confiáveis."
    end
  end
end
