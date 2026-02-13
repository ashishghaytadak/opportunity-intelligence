import { LightningElement, wire, track } from 'lwc';
import getOpportunities from '@salesforce/apex/OpportunityScoreboardController.getOpportunities';

const CATEGORY_OPTIONS = [
    { label: 'All', value: 'All' },
    { label: 'Hot', value: 'Hot' },
    { label: 'Warm', value: 'Warm' },
    { label: 'Cold', value: 'Cold' }
];

export default class OpportunityScoreboard extends LightningElement {
    @track opportunities = [];
    @track selectedCategory = 'All';
    @track sortField = 'Opportunity_Score__c';
    @track sortDir = 'desc'; // 'asc' or 'desc'
    @track error;

    categoryOptions = CATEGORY_OPTIONS;

    @wire(getOpportunities)
    wiredOpportunities({ error, data }) {
        if (data) {
            this.opportunities = data.map(opp => this.enrichOpportunity(opp));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.opportunities = [];
        }
    }

    enrichOpportunity(opp) {
        const score = opp.Opportunity_Score__c != null ? opp.Opportunity_Score__c : 0;
        const scorePercent = Math.min(100, Math.max(0, score));
        let barColor = '#c23934'; // Cold - red
        if (score >= 70) barColor = '#2e844a'; // Hot - green
        else if (score >= 40) barColor = '#fe9339'; // Warm - orange/yellow

        return {
            ...opp,
            recordUrl: '/lightning/r/Opportunity/' + opp.Id + '/view',
            formattedAmount: opp.Amount != null
                ? new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(opp.Amount)
                : '-',
            formattedCloseDate: opp.CloseDate != null
                ? new Date(opp.CloseDate).toLocaleDateString()
                : '-',
            scoreDisplay: scorePercent.toFixed(1),
            scoreBarStyle: `width: ${scorePercent}%; background-color: ${barColor}`,
            categoryBadgeClass: `slds-badge badge-${(opp.Score_Category__c || 'Cold').toLowerCase()}`
        };
    }

    get hasOpportunities() {
        return this.filteredAndSortedOpportunities && this.filteredAndSortedOpportunities.length > 0;
    }

    get filteredAndSortedOpportunities() {
        let result = [...this.opportunities];
        if (this.selectedCategory !== 'All') {
            result = result.filter(opp => opp.Score_Category__c === this.selectedCategory);
        }
        result.sort((a, b) => {
            let aVal = a[this.sortField];
            let bVal = b[this.sortField];
            if (aVal == null) aVal = this.sortField === 'Amount' ? 0 : '';
            if (bVal == null) bVal = this.sortField === 'Amount' ? 0 : '';
            if (typeof aVal === 'number' && typeof bVal === 'number') {
                return this.sortDir === 'asc' ? aVal - bVal : bVal - aVal;
            }
            const aStr = String(aVal);
            const bStr = String(bVal);
            const cmp = aStr.localeCompare(bStr);
            return this.sortDir === 'asc' ? cmp : -cmp;
        });
        return result;
    }

    get totalOpenOpps() {
        return this.filteredAndSortedOpportunities.length;
    }

    get averageScore() {
        const opps = this.filteredAndSortedOpportunities;
        if (opps.length === 0) return '0.0';
        const sum = opps.reduce((acc, o) => acc + (o.Opportunity_Score__c || 0), 0);
        return (sum / opps.length).toFixed(1);
    }

    get hotCount() {
        return this.opportunities.filter(o => o.Score_Category__c === 'Hot').length;
    }

    get warmCount() {
        return this.opportunities.filter(o => o.Score_Category__c === 'Warm').length;
    }

    get coldCount() {
        return this.opportunities.filter(o => o.Score_Category__c === 'Cold').length;
    }

    get sortDirection() {
        return this.sortDir === 'asc' ? '↑' : '↓';
    }

    get sortByName() { return this.sortField === 'Name'; }
    get sortByStage() { return this.sortField === 'StageName'; }
    get sortByAmount() { return this.sortField === 'Amount'; }
    get sortByScore() { return this.sortField === 'Opportunity_Score__c'; }
    get sortByCloseDate() { return this.sortField === 'CloseDate'; }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
    }

    handleSortName(event) {
        event.preventDefault();
        this.doSort('Name');
    }
    handleSortStage(event) {
        event.preventDefault();
        this.doSort('StageName');
    }
    handleSortAmount(event) {
        event.preventDefault();
        this.doSort('Amount');
    }
    handleSortScore(event) {
        event.preventDefault();
        this.doSort('Opportunity_Score__c');
    }
    handleSortCloseDate(event) {
        event.preventDefault();
        this.doSort('CloseDate');
    }
    doSort(field) {
        if (this.sortField === field) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortField = field;
            this.sortDir = 'desc';
        }
    }
}
