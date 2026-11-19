// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
import "Chart.bundle"

if (window.Chart && window.matchMedia("(prefers-color-scheme: dark)").matches) {
  window.Chart.defaults.color = "#a3b1c6"
  window.Chart.defaults.borderColor = "rgba(148, 163, 184, 0.18)"
}
