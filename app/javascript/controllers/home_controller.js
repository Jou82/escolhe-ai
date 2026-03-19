import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.setupScrollReveal()
    this.setupNavbarScroll()
    this.setupSmoothScroll()
  }

  setupScrollReveal() {
    const fadeElements = document.querySelectorAll('.fade-in')

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible')
          observer.unobserve(entry.target)
        }
      })
    }, {
      threshold: 0.15,
      rootMargin: '0px 0px -50px 0px'
    })

    fadeElements.forEach(el => observer.observe(el))
  }

  setupNavbarScroll() {
    const navbar = document.querySelector('.navbar')

    window.addEventListener('scroll', () => {
      if (window.scrollY > 60) {
        navbar.classList.add('scrolled')
      } else {
        navbar.classList.remove('scrolled')
      }
    })
  }

  setupSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', function (e) {
        e.preventDefault()
        const target = document.querySelector(this.getAttribute('href'))
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' })
        }
      })
    })
  }
}
