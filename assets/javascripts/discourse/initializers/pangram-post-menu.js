import { withPluginApi } from "discourse/lib/plugin-api";
import PangramScanButton from "../components/pangram-scan-button";

export default {
  name: "pangram-post-menu",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings?.pangram_enabled) {
      return;
    }

    withPluginApi("1.0.0", (api) => {
      // 1. Tell Ember to track these properties on Post models for EVERYONE.
      // This is necessary so `setProperties` triggers re-renders on the frontend.
      api.addTrackedPostProperties(
        "pangram_ai_fraction",
        "pangram_ai_assisted_fraction",
        "pangram_human_fraction",
        "pangram_confidence",
        "pangram_checked_at",
        "pangram_scanned_version",
        "pangram_history"
      );

      // 2. Add the manual scan button to the post action menu
      if (api.registerValueTransformer) {
        api.registerValueTransformer(
          "post-menu-buttons",
          ({
            value: dag,
            context: { lastHiddenButtonKey, secondLastHiddenButtonKey },
          }) => {
            dag.add("pangram-scan", PangramScanButton, {
              before: lastHiddenButtonKey,
              after: secondLastHiddenButtonKey,
            });
          }
        );
      }
    });
  },
};
