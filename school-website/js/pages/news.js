// Public page: news
pages.news=async function(){return `<section class="s"><div class="w"><h1>News</h1>${newsList(await news())}</div></section>`};
