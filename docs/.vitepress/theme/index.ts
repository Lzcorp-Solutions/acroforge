import DefaultTheme from "vitepress/theme";
import VersionBadge from "./components/VersionBadge.vue";
import version from "../generated/version.json";
import "./style.css";

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component("VersionBadge", VersionBadge);
    // Exposed for `{{ $version }}` interpolation inside `-vue` code fences,
    // so terminal/YAML examples track lib/acroforge/version.rb too.
    app.config.globalProperties.$version = version.version;
  }
};
