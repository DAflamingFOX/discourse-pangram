import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { i18n } from "discourse-i18n";

const manageSubscription = modifier((element, [post, component]) => {
  if (!post || !post.id) {
    return;
  }

  const channel = `/pangram/posts/${post.id}`;
  component.messageBus.subscribe(channel, component.handlePangramUpdate);

  return () => {
    component.messageBus.unsubscribe(channel, component.handlePangramUpdate);
  };
});

export default class PangramBadge extends Component {
  // eslint-disable-next-line discourse/no-unused-services
  @service messageBus;
  @service siteSettings;

  @tracked updateCount = 0;

  get showReportLink() {
    this.updateCount;
    return (
      this.siteSettings.pangram_enable_public_dashboard_link &&
      this.post?.pangram_dashboard_link
    );
  }

  @action
  handlePangramUpdate(data) {
    if (!this.post) {
      return;
    }
    this.post.setProperties({
      pangram_ai_fraction: data.ai_fraction,
      pangram_ai_assisted_fraction: data.ai_assisted_fraction,
      pangram_human_fraction: data.human_fraction,
      pangram_confidence: data.confidence,
      pangram_dashboard_link: data.public_dashboard_link,
      pangram_checked_at: data.checked_at,
      pangram_scanned_version: data.scanned_version || this.post.version,
    });
    this.updateCount++;
  }

  get post() {
    return this.args.post;
  }

  get aiFraction() {
    this.updateCount;
    return this.post?.pangram_ai_fraction;
  }

  get aiAssistedFraction() {
    this.updateCount;
    return this.post?.pangram_ai_assisted_fraction;
  }

  get humanFraction() {
    this.updateCount;
    return this.post?.pangram_human_fraction;
  }

  get confidence() {
    this.updateCount;
    return this.post?.pangram_confidence;
  }

  get isVisible() {
    return this.aiFraction !== undefined && this.aiFraction !== null;
  }

  get aiPercentage() {
    return Math.round((this.aiFraction || 0) * 100);
  }

  get aiAssistedPercentage() {
    return Math.round((this.aiAssistedFraction || 0) * 100);
  }

  get humanPercentage() {
    return Math.round((this.humanFraction || 0) * 100);
  }

  get severityClass() {
    const pct = this.aiPercentage;
    if (pct >= 70) {
      return "pangram-badge--high";
    } else if (pct >= 35) {
      return "pangram-badge--medium";
    }
    return "pangram-badge--low";
  }

  get tooltipText() {
    return `${i18n("pangram.badge_title")}: ${this.aiPercentage}% ${i18n("pangram.ai_fraction")}, ${this.aiAssistedPercentage}% ${i18n("pangram.ai_assisted_fraction")}, ${this.humanPercentage}% ${i18n("pangram.human_fraction")}`;
  }

  <template>
    <span
      {{manageSubscription this.post this}}
      class="pangram-subscription-manager"
      style="display:none;"
    ></span>
    {{#if this.isVisible}}
      <div class="pangram-badge-wrapper">
        {{#if this.showReportLink}}
          <a
            href={{this.post.pangram_dashboard_link}}
            target="_blank"
            rel="noopener noreferrer"
            class="pangram-badge {{this.severityClass}}"
            title={{this.tooltipText}}
            style="text-decoration: none; color: inherit;"
          >
            <div class="pangram-badge__inner">
              <span class="pangram-badge__stat">
                <span
                  class="pangram-custom-icon pangram-icon-robot"
                  title="AI"
                ></span>
                <span class="pangram-badge__value">{{this.aiPercentage}}%</span>
              </span>

              <span class="pangram-badge__divider">|</span>

              <span class="pangram-badge__stat">
                <span
                  class="pangram-custom-icon pangram-icon-pencil-ai"
                  title="AI Assisted"
                ></span>
                <span
                  class="pangram-badge__value"
                >{{this.aiAssistedPercentage}}%</span>
              </span>

              <span class="pangram-badge__divider">|</span>

              <span class="pangram-badge__stat">
                <span
                  class="pangram-custom-icon pangram-icon-pencil"
                  title="Human"
                ></span>
                <span
                  class="pangram-badge__value"
                >{{this.humanPercentage}}%</span>
              </span>

              {{#if this.confidence}}
                <span class="pangram-badge__divider">-</span>
                <span
                  class="pangram-badge__confidence"
                >{{this.confidence}}</span>
              {{/if}}
            </div>
          </a>
        {{else}}
          <div
            class="pangram-badge {{this.severityClass}}"
            title={{this.tooltipText}}
          >
            <div class="pangram-badge__inner">
              <span class="pangram-badge__stat">
                <span
                  class="pangram-custom-icon pangram-icon-robot"
                  title="AI"
                ></span>
                <span class="pangram-badge__value">{{this.aiPercentage}}%</span>
              </span>

              <span class="pangram-badge__divider">|</span>

              <span class="pangram-badge__stat">
                <span
                  class="pangram-custom-icon pangram-icon-pencil-ai"
                  title="AI Assisted"
                ></span>
                <span
                  class="pangram-badge__value"
                >{{this.aiAssistedPercentage}}%</span>
              </span>

              <span class="pangram-badge__divider">|</span>

              <span class="pangram-badge__stat">
                <span
                  class="pangram-custom-icon pangram-icon-pencil"
                  title="Human"
                ></span>
                <span
                  class="pangram-badge__value"
                >{{this.humanPercentage}}%</span>
              </span>

              {{#if this.confidence}}
                <span class="pangram-badge__divider">-</span>
                <span
                  class="pangram-badge__confidence"
                >{{this.confidence}}</span>
              {{/if}}
            </div>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
