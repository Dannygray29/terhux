import type {Grade,Measurement,TestResult} from "../types/network";
export function gradeForScore(score:number):Grade { if(score>=90)return "Excellent"; if(score>=75)return "Good"; if(score>=55)return "Fair"; if(score>=30)return "Poor"; return "Critical"; }
export function diagnose(m:Measurement):Pick<TestResult,"score"|"grade"|"explanations"|"recommendations"> {
 let score=100,e:string[]=[],r:string[]=[];
 if(m.latencyMs==null){score-=25;e.push("Latency could not be measured.");}else if(m.latencyMs>250){score-=30;e.push(`Latency is high at ${Math.round(m.latencyMs)} ms.`);r.push("Test again at another time and compare Wi‑Fi with mobile data to identify congestion or routing issues.");}else if(m.latencyMs>100){score-=15;e.push(`Latency is elevated at ${Math.round(m.latencyMs)} ms.`);}
 if(m.jitterMs!=null&&m.jitterMs>40){score-=15;e.push(`Jitter is high at ${Math.round(m.jitterMs)} ms.`);r.push("Investigate Wi‑Fi interference, signal quality, or network congestion.");}
 if(m.packetLossPct!=null&&m.packetLossPct>5){score-=30;e.push(`Packet loss is significant at ${m.packetLossPct.toFixed(1)}%.`);r.push("Move closer to the router or compare another network; persistent loss may indicate routing or carrier problems.");}else if(m.packetLossPct!=null&&m.packetLossPct>1){score-=12;e.push(`Some packet loss was detected (${m.packetLossPct.toFixed(1)}%).`);}
 if(m.dnsMs!=null&&m.dnsMs>300){score-=15;e.push(`DNS response time is slow at ${Math.round(m.dnsMs)} ms.`);r.push("Try a reputable alternative DNS resolver, then repeat the test.");}
 if(m.downloadMbps!=null&&m.downloadMbps<5){score-=15;e.push(`Download throughput is low at ${m.downloadMbps.toFixed(1)} Mbps.`);r.push("Check signal strength, background traffic, and congestion.");}
 if(m.uploadMbps!=null&&m.uploadMbps<1){score-=8;e.push(`Upload throughput is low at ${m.uploadMbps.toFixed(1)} Mbps.`);}
 if(m.downloadMbps!=null&&m.latencyMs!=null&&m.downloadMbps>=20&&m.latencyMs>150)e.push("Download speed is relatively good while latency is poor, so bandwidth is probably not the main issue.");
 if(!m.reachable){score=0;e.push("The measurement endpoint could not be reached.");r.push("Check whether the device is connected and retry.");}
 if(!e.length)e.push("No major issue was detected by this test.");if(!r.length)r.push("No urgent optimization is indicated. Keep monitoring for changes over time.");
 score=Math.max(0,Math.min(100,Math.round(score)));return{score,grade:gradeForScore(score),explanations:e,recommendations:r};
}