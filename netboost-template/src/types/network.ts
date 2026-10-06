export type Grade="Excellent"|"Good"|"Fair"|"Poor"|"Critical";
export interface Measurement { latencyMs:number|null;jitterMs:number|null;packetLossPct:number|null;dnsMs:number|null;downloadMbps:number|null;uploadMbps:number|null;stabilityPct:number|null;reachable:boolean;durationMs:number;endpoint:string;timestamp:number; }
export interface TestResult extends Measurement { score:number;grade:Grade;explanations:string[];recommendations:string[]; }
export interface NetworkSnapshot { connectionType:string;effectiveType:string|null;downlinkMbps:number|null;rttMs:number|null;saveData:boolean|null; }
export type OptimizationKind="safe"|"manual";
export interface OptimizationAction {id:string;title:string;reason:string;steps:string[];kind:OptimizationKind;priority:number;}
export interface OptimizationPlan {score:number;summary:string;actions:OptimizationAction[];}
export type OptimizationKind="safe"|"manual";
export interface OptimizationAction {id:string;title:string;reason:string;steps:string[];kind:OptimizationKind;priority:number;}
export interface OptimizationPlan {score:number;summary:string;actions:OptimizationAction[];}
