// Public page: contact
pages.contact=()=>`<section class="s"><div class="w"><h1>Contact us</h1><form class="f" data-f="contact">${field('Name','name')}${field('Email','email','email')}<label>Message<textarea name="body" rows="4" required></textarea></label><button class="btn">Send message</button><div class="out"></div></form></div></section>`;
