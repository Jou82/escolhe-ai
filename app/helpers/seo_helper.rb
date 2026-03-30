# app/helpers/seo_helper.rb
module SeoHelper
  # Gera o título completo da página
  # Uso: <%= seo_title("Comparar Notebooks") %>
  def seo_title(page_title = nil)
    base_title = "Escolhe Aí | Algoritmo Personalizado de Recomendação de Filmes"

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
      "Escolhe Aí: diga 3 produções que você ama e nosso algoritmo personalizado recomenda 3 filmes perfeitos para você. Análise inteligente de temas, estética e emoção. Descubra trailers e onde assistir. Grátis!"
    end
  end

  # Gera título para Open Graph (compartilhamento)
  def og_title(title = nil)
    if title.present?
      title
    else
      "Escolhe Aí - Algoritmo que entende seu gosto"
    end
  end

  # Gera descrição para Open Graph (compartilhamento)
  def og_description(description = nil)
    if description.present?
      description
    else
      "Compartilhe 3 produções que marcaram você. Nosso algoritmo personalizado analisa temas, estética e emoção para encontrar o match perfeito para sua noite de cinema. Comece grátis!"
    end
  end
end
