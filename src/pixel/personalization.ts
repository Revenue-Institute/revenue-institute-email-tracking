/**
 * Personalization Module
 * Fetches visitor-specific data and enables dynamic content
 */

export interface PersonalizationData {
  personalized: boolean;
  firstName?: string;
  lastName?: string;
  company?: string;
  intentScore?: number;
  engagementLevel?: string;
  viewedPricing?: boolean;
  submittedForm?: boolean;
}

export class Personalizer {
  private data: PersonalizationData | null = null;
  private endpoint: string;
  private visitorId: string | null;

  constructor(endpoint: string, visitorId: string | null) {
    this.endpoint = endpoint;
    this.visitorId = visitorId;
  }

  /**
   * Fetch personalization data from Worker
   */
  async fetch(): Promise<PersonalizationData> {
    if (!this.visitorId) {
      return { personalized: false };
    }

    try {
      const response = await fetch(`${this.endpoint}?vid=${this.visitorId}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        return { personalized: false };
      }

      this.data = await response.json();
      return this.data!;
    } catch (error) {
      console.error('Failed to fetch personalization data:', error);
      return { personalized: false };
    }
  }

  /**
   * Apply personalization to page elements
   */
  async personalize(): Promise<void> {
    if (!this.data) {
      this.data = await this.fetch();
    }

    if (!this.data.personalized) {
      return;
    }

    // Replace data attributes
    document.querySelectorAll('[data-personalize]').forEach(element => {
      const field = element.getAttribute('data-personalize');
      if (field && this.data && field in this.data) {
        const value = this.data[field as keyof PersonalizationData];
        if (value !== undefined && value !== null) {
          element.textContent = String(value);
        }
      }
    });

    // Show/hide elements based on conditions
    document.querySelectorAll('[data-show-if]').forEach(element => {
      const condition = element.getAttribute('data-show-if');
      if (this.evaluateCondition(condition)) {
        (element as HTMLElement).style.display = '';
      } else {
        (element as HTMLElement).style.display = 'none';
      }
    });

    // Add classes based on engagement level
    if (this.data.engagementLevel) {
      document.body.classList.add(`engagement-${this.data.engagementLevel}`);
    }

    // Trigger custom event for app integration
    window.dispatchEvent(new CustomEvent('personalized', {
      detail: this.data
    }));
  }

  /**
   * Evaluate condition expressions
   */
  private evaluateCondition(condition: string | null): boolean {
    if (!condition || !this.data) return false;

    // Simple condition evaluation
    // Supports: viewedPricing, submittedForm, intentScore>50, engagementLevel=hot
    try {
      if (condition.includes('>')) {
        const [field, value] = condition.split('>');
        const fieldValue = this.data[field.trim() as keyof PersonalizationData];
        return typeof fieldValue === 'number' && fieldValue > parseFloat(value);
      }

      if (condition.includes('=')) {
        const [field, value] = condition.split('=');
        const fieldValue = this.data[field.trim() as keyof PersonalizationData];
        return String(fieldValue) === value.trim();
      }

      // Boolean field
      return Boolean(this.data[condition as keyof PersonalizationData]);
    } catch (e) {
      return false;
    }
  }

  /**
   * Get personalization data
   */
  getData(): PersonalizationData | null {
    return this.data;
  }
}

// Add to tracker
declare global {
  interface Window {
    Personalizer: typeof Personalizer;
  }
}

window.Personalizer = Personalizer;

export default Personalizer;


