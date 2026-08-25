import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class PangramScanButton extends Component {
  static shouldRender(args, state) {
    if (!state.siteSettings?.pangram_enabled || !state.currentUser) {
      return false;
    }

    if (state.currentUser.staff) {
      return true;
    }

    const minTl = state.siteSettings.pangram_min_trust_level_to_scan;
    return state.currentUser.trust_level >= minTl;
  }

  static hidden() {
    // ALWAYS return true to force the button into the 3-dot (Show More) menu.
    // If this returned false, it would render on the top level (next to Reply).
    return true;
  }

  @service toasts;
  @service messageBus;

  @tracked scanning = false;

  get isAlreadyScanned() {
    return (
      this.post?.pangram_ai_fraction !== undefined &&
      this.post?.pangram_ai_fraction !== null &&
      this.post?.pangram_scanned_version === this.post?.version
    );
  }

  get buttonTitle() {
    if (this.isAlreadyScanned) {
      return "pangram.already_scanned_title";
    }
    return "pangram.scan_action_title";
  }

  get post() {
    return this.args.post;
  }

  @action
  async scan() {
    const post = this.post;

    if (!post?.id || this.scanning) {
      return;
    }

    if (this.isAlreadyScanned) {
      if (this.toasts?.info) {
        this.toasts.info({
          data: { message: i18n("pangram.already_scanned") },
        });
      }
      return;
    }

    this.scanning = true;

    if (this.toasts?.info) {
      this.toasts.info({ data: { message: i18n("pangram.scanning") } });
    }

    const channel = `/pangram/posts/${post.id}`;
    if (this.messageBus?.subscribe) {
      this.messageBus.subscribe(channel, (data) => {
        if (data?.post_id === post.id) {
          post.setProperties({
            pangram_ai_fraction: data.ai_fraction,
            pangram_ai_assisted_fraction: data.ai_assisted_fraction,
            pangram_human_fraction: data.human_fraction,
            pangram_confidence: data.confidence,
            pangram_task_id: data.task_id,
            pangram_dashboard_link: data.public_dashboard_link,
            pangram_checked_at: data.checked_at,
            pangram_scanned_version: data.scanned_version || post.version,
          });

          if (this.toasts?.success) {
            this.toasts.success({
              data: { message: i18n("pangram.scan_completed") },
            });
          }

          this.messageBus.unsubscribe(channel);
          this.scanning = false;
        }
      });
    }

    try {
      const url = `/pangram/posts/${post.id}/scan`;
      const response = await ajax(url, {
        type: "POST",
      });

      if (response?.ai_fraction !== undefined) {
        post.setProperties({
          pangram_ai_fraction: response.ai_fraction,
          pangram_ai_assisted_fraction: response.ai_assisted_fraction,
          pangram_human_fraction: response.human_fraction,
          pangram_confidence: response.confidence,
          pangram_task_id: response.task_id,
          pangram_dashboard_link: response.public_dashboard_link,
          pangram_checked_at: response.checked_at,
          pangram_scanned_version: response.scanned_version || post.version,
        });

        if (this.toasts?.success) {
          this.toasts.success({
            data: { message: i18n("pangram.scan_completed") },
          });
        }
      } else if (response?.cached) {
        if (this.toasts?.info) {
          this.toasts.info({
            data: { message: i18n("pangram.already_scanned") },
          });
        }
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.scanning = false;
    }
  }

  get isDisabled() {
    return this.isAlreadyScanned || this.scanning;
  }

  <template>
    <DButton
      class="post-action-menu__pangram-scan"
      ...attributes
      @action={{this.scan}}
      @disabled={{this.isDisabled}}
      @title={{this.buttonTitle}}
    >
      <span
        class="pangram-custom-icon pangram-icon-qr-scan"
        style="background-color: currentColor; width: 1.5em; height: 1.5em; margin: 0 -0.25em;"
      ></span>
    </DButton>
  </template>
}
