export default ScrollToTopHook = {
  mounted() {
    this.handleEvent("scroll-to-top", () => {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  },
};
