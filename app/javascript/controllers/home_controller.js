import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chips", "form"]

  connect() {
    this.setupScrollReveal()
    this.setupNavbarScroll()
    this.setupSmoothScroll()
    this.setupParallaxOrbs()
    this.setupFormGuard()
  }

  setupFormGuard() {
    const form = document.querySelector('.search-box')
    if (!form) return

    form.addEventListener('submit', (event) => {
      const signed = document.querySelector('meta[name="user-signed-in"]')?.content === 'true'
      if (!signed) {
        event.preventDefault()
        event.stopImmediatePropagation()
        // Abrir o modal de login
        const loginModal = this.application.getControllerForElementAndIdentifier(
          document.body, 'login-modal'
        )
        if (loginModal) loginModal.open()
      }
    })
  }

  // ===== SCROLL REVEAL =====
  setupScrollReveal() {
    const fadeElements = document.querySelectorAll('.fade-in')

    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry, index) => {
        if (entry.isIntersecting) {
          // Staggered delay for grouped elements
          const delay = index * 100
          setTimeout(() => {
            entry.target.classList.add('visible')
          }, delay)
          observer.unobserve(entry.target)
        }
      })
    }, {
      threshold: 0.15,
      rootMargin: '0px 0px -40px 0px'
    })

    fadeElements.forEach(el => observer.observe(el))
  }

  // ===== NAVBAR SCROLL EFFECT =====
  setupNavbarScroll() {
    const navbar = document.querySelector('.site-navbar')
    if (!navbar) return

    window.addEventListener('scroll', () => {
      if (window.scrollY > 60) {
        navbar.classList.add('scrolled')
      } else {
        navbar.classList.remove('scrolled')
      }
    })
  }

  // ===== SMOOTH SCROLL FOR ANCHOR LINKS =====
  setupSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', function (e) {
        const href = this.getAttribute('href')
        if (!href || href === '#') return
        e.preventDefault()
        const target = document.querySelector(href)
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' })
        }
      })
    })
  }

  // ===== PARALLAX ORB MOVEMENT ON MOUSE =====
  setupParallaxOrbs() {
    const hero = document.querySelector('.hero')
    if (!hero) return

    const orbs = document.querySelectorAll('.orb')

    hero.addEventListener('mousemove', (e) => {
      const rect = hero.getBoundingClientRect()
      const x = (e.clientX - rect.left) / rect.width - 0.5
      const y = (e.clientY - rect.top) / rect.height - 0.5

      orbs.forEach((orb, index) => {
        const speed = (index + 1) * 15
        const translateX = x * speed
        const translateY = y * speed
        orb.style.transform = `translate(${translateX}px, ${translateY}px)`
      })
    })

    hero.addEventListener('mouseleave', () => {
      orbs.forEach((orb) => {
        orb.style.transform = 'translate(0, 0)'
        orb.style.transition = 'transform 0.6s ease-out'
        setTimeout(() => {
          orb.style.transition = ''
        }, 600)
      })
    })
  }

  // ===== GENRE CHIP CLICK =====
  insertChip(event) {
    const genre = event.currentTarget.dataset.genre
    const input = document.querySelector('.search-input')
    if (!input) return

    // Toggle active state
    event.currentTarget.classList.toggle('active')

    // Get current value and append/remove genre
    const currentValue = input.value.trim()
    const genres = currentValue ? currentValue.split(',').map(g => g.trim()).filter(Boolean) : []

    const genreIndex = genres.indexOf(genre)
    if (genreIndex > -1) {
      genres.splice(genreIndex, 1)
    } else {
      genres.push(genre)
    }

    input.value = genres.join(', ')
    input.focus()
  }

  // ===== SCROLL TO SEARCH FROM CTA =====
  scrollToSearch(event) {
    event.preventDefault()
    window.scrollTo({ top: 0, behavior: 'smooth' })
    setTimeout(() => {
      const input = document.querySelector('.search-input')
      if (input) input.focus()
    }, 600)
  }
}
