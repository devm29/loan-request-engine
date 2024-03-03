import { Controller } from 'stimulus';

export default class extends Controller {
  connect() {
    this.element.querySelectorAll('.flash').forEach(flash => {
      setTimeout(() => {
        flash.style.transition = 'opacity 0.5s';
        flash.style.opacity = '0';
      }, 3000); 

      flash.addEventListener('transitionend', () => {
        flash.remove();
      });
    });
  }
}
