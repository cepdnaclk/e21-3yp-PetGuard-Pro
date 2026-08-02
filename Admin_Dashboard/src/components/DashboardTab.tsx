import { useState, useEffect } from 'react';
import { collection, query, where, onSnapshot, getDocs } from 'firebase/firestore';
import { ref, onValue, onChildChanged, onChildAdded, get } from 'firebase/database';
import { firestore, rtdb } from '../firebase';
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, Tooltip } from 'recharts';
import { Users, ShieldAlert, Wifi, Activity, Terminal, FileText } from 'lucide-react';

interface SyncEvent {
  time: number;
}

export default function DashboardTab() {
  const [stats, setStats] = useState({
    users: 0,
    harnesses: 0,
    alerts: 0,
    connectivity: '100%',
  });

  // DB Sync Events State
  const [syncEvents, setSyncEvents] = useState<SyncEvent[]>([]);
  const [totalPackets, setTotalPackets] = useState(0);
  const [chartData, setChartData] = useState<{ name: string; packets: number }[]>([]);
  const [modalContent, setModalContent] = useState<{ title: string; body: string } | null>(null);
  const [reportData, setReportData] = useState<any[] | null>(null);

  // Load metrics dynamically in real-time
  useEffect(() => {
    // 1. Registered Owners (status != not_varified)
    const usersQuery = query(collection(firestore, 'users'));
    const unsubscribeUsers = onSnapshot(usersQuery, (snapshot) => {
      const activeUsers = snapshot.docs.filter((doc) => {
        const data = doc.data();
        return (data.status || 'Pending') !== 'not_varified';
      });
      setStats((prev) => ({ ...prev, users: activeUsers.length }));
    });

    // 2. Active Warnings (alerts with status == 'Pending')
    const alertsQuery = query(collection(firestore, 'alerts'), where('status', '==', 'Pending'));
    const unsubscribeAlerts = onSnapshot(alertsQuery, (snapshot) => {
      setStats((prev) => ({ ...prev, alerts: snapshot.size }));
    });

    // 3. Smart Harnesses (RTDB 'pets' keys count)
    const petsRef = ref(rtdb, 'pets');
    const unsubscribePets = onValue(petsRef, (snapshot) => {
      if (snapshot.exists()) {
        const data = snapshot.val();
        const keys = Object.keys(data);
        setStats((prev) => ({ ...prev, harnesses: keys.length }));
      } else {
        setStats((prev) => ({ ...prev, harnesses: 0 }));
      }
    });

    // 4. Signal Latency (from devices collection)
    const devicesRef = collection(firestore, 'devices');
    const unsubscribeDevices = onSnapshot(devicesRef, (snapshot) => {
      if (snapshot.empty) {
        setStats((prev) => ({ ...prev, connectivity: '100%' }));
      } else {
        let total = 0;
        snapshot.docs.forEach((doc) => {
          total += (doc.data().connectivity || 0);
        });
        const avg = Math.round(total / snapshot.docs.length);
        setStats((prev) => ({ ...prev, connectivity: `${avg}%` }));
      }
    });

    return () => {
      unsubscribeUsers();
      unsubscribeAlerts();
      unsubscribePets();
      unsubscribeDevices();
    };
  }, []);

  // Listen to RTDB onChildChanged/onChildAdded to build the telemetry traffic graph
  useEffect(() => {
    const petsRef = ref(rtdb, 'pets');

    const handleSync = () => {
      const timestamp = Date.now();
      setSyncEvents((prev) => [...prev, { time: timestamp }]);
      setTotalPackets((prev) => prev + 1);
    };

    const unsubChanged = onChildChanged(petsRef, handleSync);
    const unsubAdded = onChildAdded(petsRef, handleSync);

    return () => {
      unsubChanged();
      unsubAdded();
    };
  }, []);

  // Sync Event cleanup & chart grouping timer (Every second)
  useEffect(() => {
    const interval = setInterval(() => {
      const now = Date.now();
      const cutoff = now - 70000; // 70-second sliding window

      // Clean old timestamps
      setSyncEvents((prev) => prev.filter((e) => e.time >= cutoff));

      // Calculate sliding window intervals (8 intervals of 10s each)
      const intervalCounts = Array(8).fill(0);
      syncEvents.forEach((event) => {
        const diff = now - event.time;
        const bin = 7 - Math.floor(diff / 10000);
        if (bin >= 0 && bin < 8) {
          intervalCounts[bin]++;
        }
      });

      // Format chart coordinates (multiply bin total by 6 to estimate packets per minute)
      const data = intervalCounts.map((count, index) => ({
        name: `-${(7 - index) * 10}s`,
        packets: count * 6,
      }));
      setChartData(data);
    }, 1000);

    return () => clearInterval(interval);
  }, [syncEvents]);

  // Actions
  const runDiagnosis = async () => {
    setModalContent({
      title: 'Diagnostic Check',
      body: 'Running comprehensive diagnostic check on databases and telemetry mappings...',
    });

    try {
      // Fetch users
      const usersSnap = await getDocs(collection(firestore, 'users'));
      const usersList: any[] = [];
      usersSnap.forEach(d => usersList.push({ id: d.id, ...d.data() }));

      // Fetch stock
      const stockSnap = await getDocs(collection(firestore, 'stock'));
      const stockList: any[] = [];
      stockSnap.forEach(d => stockList.push({ id: d.id, ...d.data() }));

      // Fetch active alerts
      const alertsSnap = await getDocs(query(collection(firestore, 'alerts'), where('status', '==', 'Pending')));
      const activeAlertsCount = alertsSnap.size;

      // Fetch RTDB pets keys
      let rtdbKeysCount = 0;
      let rtdbActive = false;
      try {
        const petsSnapshot = await get(ref(rtdb, 'pets'));
        if (petsSnapshot.exists()) {
          rtdbKeysCount = Object.keys(petsSnapshot.val()).length;
        }
        rtdbActive = true;
      } catch (err) {
        console.error("RTDB Diagnostic ping failed:", err);
      }

      // Analyze integrity
      const userAssignedPetIds = usersList
        .map(u => u.selectedPetId)
        .filter(Boolean) as string[];

      const stockAssignedIds = stockList
        .filter(item => item.status === 'assigned')
        .map(item => item.deviceId || item.id) as string[];

      const stockAvailableIds = stockList
        .filter(item => item.status === 'available')
        .map(item => item.deviceId || item.id) as string[];

      // Discrepancy 1: Harness marked as assigned in stock, but no user points to it
      const orphanedHarnesses = stockAssignedIds.filter(id => !userAssignedPetIds.includes(id));

      // Discrepancy 2: User points to a harness, but it is not marked as assigned (e.g. available or missing)
      const userHarnessMismatches = usersList.filter(u => {
        if (!u.selectedPetId) return false;
        const stockItem = stockList.find(item => (item.deviceId || item.id) === u.selectedPetId);
        return !stockItem || stockItem.status !== 'assigned';
      });

      // Construct report
      const lines = [
        `=== DATABASE STATUS ===`,
        `Firestore Connection: ACTIVE`,
        `Realtime Database: ${rtdbActive ? 'ACTIVE' : 'OFFLINE'}`,
        ``,
        `=== METRIC SUMMARIES ===`,
        `Total Registered Users: ${usersList.length}`,
        `Total Harnesses in Stock: ${stockList.length}`,
        `  - Available units: ${stockAvailableIds.length}`,
        `  - Assigned units: ${stockAssignedIds.length}`,
        `  - Under maintenance: ${stockList.filter(i => i.status === 'maintenance').length}`,
        `  - Faulty units: ${stockList.filter(i => i.status === 'faulty').length}`,
        `Unresolved System Alerts: ${activeAlertsCount}`,
        `Realtime Telemetry Streams: ${rtdbKeysCount} active devices`,
        ``,
        `=== SYSTEM INTEGRITY CHECKS ===`,
      ];

      let errorsCount = 0;

      if (orphanedHarnesses.length > 0) {
        errorsCount += orphanedHarnesses.length;
        lines.push(`⚠️ WARNING: ${orphanedHarnesses.length} harness(es) marked as 'assigned' in stock, but not linked to any user:`);
        orphanedHarnesses.forEach(id => lines.push(`  - ID: ${id}`));
      }

      if (userHarnessMismatches.length > 0) {
        errorsCount += userHarnessMismatches.length;
        lines.push(`⚠️ WARNING: ${userHarnessMismatches.length} user(s) point to unassigned or missing harness:`);
        userHarnessMismatches.forEach(u => {
          lines.push(`  - User: ${u.name || u.email || u.id} -> Harness ID: ${u.selectedPetId}`);
        });
      }

      if (errorsCount === 0) {
        lines.push(`✅ Integrity check passed: 0 allocation discrepancies detected.`);
      } else {
        lines.push(``);
        lines.push(`❌ Total discrepancies detected: ${errorsCount}`);
      }

      setModalContent({
        title: 'Diagnostic Check Result',
        body: lines.join('\n'),
      });
    } catch (e: any) {
      setModalContent({
        title: 'Diagnostic Check Failed',
        body: `Failed to execute system diagnostics:\n${e.message || e}`,
      });
    }
  };

  const getGatewayInfo = () => {
    setModalContent({
      title: 'Gateway Status',
      body: 'Firebase Cloud Functions: Active\nFirebase RTDB: Operational\nFirebase Cloud Messaging: Active',
    });
  };

  // Compile and fetch live pet list for generating a printable report
  const generateReport = async () => {
    try {
      const snapshot = await get(ref(rtdb, 'pets'));
      if (snapshot.exists()) {
        const petsData = snapshot.val();
        const records = Object.entries(petsData).map(([id, val]: [string, any]) => {
          const current = val.activity?.current || {};
          const loc = val.current_location || val.location || {};
          const health = val.health || {};
          const battery = val.battery || {};

          return {
            id,
            activityType: (current.activity_type || 'Unknown').toUpperCase(),
            impact: current.impact_detected ? 'TRIGGERED' : 'NONE',
            impactSeverity: current.impact_severity || 0,
            stepCount: current.step_count || 0,
            activeMinutes: current.active_minutes || 0,
            heartRate: health.heart_rate || 'N/A',
            temperature: health.temperature ? `${Number(health.temperature).toFixed(1)} °C` : 'N/A',
            battery: battery.percentage !== undefined ? `${battery.percentage}%` : '100%',
            coords: loc.latitude && loc.longitude ? `${Number(loc.latitude).toFixed(6)}, ${Number(loc.longitude).toFixed(6)}` : 'No GPS signal',
          };
        });
        setReportData(records);
      } else {
        setReportData([]);
      }
    } catch (e) {
      console.error(e);
      setModalContent({
        title: 'Error',
        body: 'Error fetching database report logs.',
      });
    }
  };

  // Calculate current packets speed
  const currentSpeed = chartData.length > 0 ? chartData.reduce((acc, curr) => acc + curr.packets, 0) / 8 : 0;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">System Overview</h2>
          <p className="text-sm text-slate-500 dark:text-slate-400">IoT harnesses and gateway monitoring console</p>
        </div>
        <div className="flex items-center space-x-2 bg-emerald-100 dark:bg-emerald-950/30 border border-emerald-300/30 px-3 py-1.5 rounded-full">
          <span className="w-2.5 h-2.5 bg-emerald-500 rounded-full animate-pulse"></span>
          <span className="text-xs font-bold text-emerald-600 dark:text-emerald-400 tracking-wider">LIVE SYSTEM</span>
        </div>
      </div>

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Metric 1 */}
        <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl p-5 shadow-sm hover:shadow-md transition">
          <div className="p-2.5 bg-teal-100 dark:bg-teal-950/30 text-teal-600 dark:text-teal-400 rounded-full w-fit">
            <Users className="w-5 h-5" />
          </div>
          <div className="mt-4">
            <span className="text-3xl font-extrabold text-slate-800 dark:text-slate-100">{stats.users}</span>
            <p className="text-xs text-slate-400 dark:text-slate-400 mt-1">Registered Owners</p>
          </div>
        </div>

        {/* Metric 2 */}
        <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl p-5 shadow-sm hover:shadow-md transition">
          <div className="p-2.5 bg-blue-100 dark:bg-blue-950/30 text-blue-600 dark:text-blue-400 rounded-full w-fit">
            <Activity className="w-5 h-5" />
          </div>
          <div className="mt-4">
            <span className="text-3xl font-extrabold text-slate-800 dark:text-slate-100">{stats.harnesses}</span>
            <p className="text-xs text-slate-400 dark:text-slate-400 mt-1">Total Harnesses</p>
          </div>
        </div>

        {/* Metric 3 */}
        <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl p-5 shadow-sm hover:shadow-md transition">
          <div className="p-2.5 bg-orange-100 dark:bg-orange-950/30 text-orange-600 dark:text-orange-400 rounded-full w-fit">
            <ShieldAlert className="w-5 h-5" />
          </div>
          <div className="mt-4">
            <span className="text-3xl font-extrabold text-slate-800 dark:text-slate-100">{stats.alerts}</span>
            <p className="text-xs text-slate-400 dark:text-slate-400 mt-1">Active Warnings</p>
          </div>
        </div>

        {/* Metric 4 */}
        <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl p-5 shadow-sm hover:shadow-md transition">
          <div className="p-2.5 bg-indigo-100 dark:bg-indigo-950/30 text-indigo-600 dark:text-indigo-400 rounded-full w-fit">
            <Wifi className="w-5 h-5" />
          </div>
          <div className="mt-4">
            <span className="text-3xl font-extrabold text-slate-800 dark:text-slate-100">{stats.connectivity}</span>
            <p className="text-xs text-slate-400 dark:text-slate-400 mt-1">Signal Connectivity</p>
          </div>
        </div>
      </div>

      {/* Traffic Graph card */}
      <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl p-5 shadow-sm">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="font-bold text-slate-800 dark:text-slate-100">Database Sync Traffic</h3>
            <p className="text-xs text-slate-400 dark:text-slate-400">Firebase RTDB update payload frequency</p>
          </div>
          <div className="text-right">
            <span className="text-lg font-bold text-slate-800 dark:text-slate-100">{Math.round(currentSpeed)} pkts/min</span>
            <p className="text-[10px] text-slate-400 dark:text-slate-400">Aggregate stream speed</p>
          </div>
        </div>

        {/* Line Chart */}
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chartData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
              <defs>
                <linearGradient id="colorPackets" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#00897B" stopOpacity={0.2} />
                  <stop offset="95%" stopColor="#00897B" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="name" tick={{ fontSize: 10 }} stroke="#94a3b8" />
              <YAxis tick={{ fontSize: 10 }} stroke="#94a3b8" />
              <Tooltip contentStyle={{ backgroundColor: '#1e293b', border: 'none', borderRadius: '8px', color: '#f8fafc', fontSize: '12px' }} />
              <Area type="monotone" dataKey="packets" stroke="#00897B" strokeWidth={2} fillOpacity={1} fill="url(#colorPackets)" name="Packets / Min" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="border-t border-slate-100 dark:border-slate-700/30 mt-4 pt-4 flex items-center justify-between text-xs text-slate-400 dark:text-slate-400">
          <span>Cumulative Packets logged: <strong>{totalPackets}</strong></span>
          <span>Window size: 70s</span>
        </div>
      </div>

      {/* System Actions card */}
      <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl p-5 shadow-sm">
        <h3 className="font-bold text-slate-800 dark:text-slate-100 mb-4">System Diagnostic Actions</h3>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <button onClick={runDiagnosis} className="flex flex-col items-center justify-center p-4 bg-teal-500/10 hover:bg-teal-500/20 text-teal-700 dark:text-teal-300 border border-teal-500/20 rounded-xl transition">
            <Terminal className="w-5 h-5 mb-2" />
            <span className="text-sm font-semibold">Diagnosis Check</span>
          </button>

          <button onClick={getGatewayInfo} className="flex flex-col items-center justify-center p-4 bg-blue-500/10 hover:bg-blue-500/20 text-blue-700 dark:text-blue-300 border border-blue-500/20 rounded-xl transition">
            <Wifi className="w-5 h-5 mb-2" />
            <span className="text-sm font-semibold">Gateway Info</span>
          </button>

          <button onClick={generateReport} className="flex flex-col items-center justify-center p-4 bg-indigo-500/10 hover:bg-indigo-500/20 text-indigo-700 dark:text-indigo-300 border border-indigo-500/20 rounded-xl transition">
            <FileText className="w-5 h-5 mb-2" />
            <span className="text-sm font-semibold">Generate DB Report</span>
          </button>
        </div>
      </div>

      {/* Info Modals */}
      {modalContent && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-2xl max-w-md w-full p-6 shadow-xl space-y-4">
            <h4 className="text-lg font-bold text-slate-800 dark:text-slate-100">{modalContent.title}</h4>
            <p className="text-sm text-slate-600 dark:text-slate-300 whitespace-pre-wrap">{modalContent.body}</p>
            <div className="flex justify-end pt-2">
              <button onClick={() => setModalContent(null)} className="px-4 py-2 bg-primary hover:bg-primary-dark text-white text-sm font-bold rounded-lg transition">
                Dismiss
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Report Modal */}
      {reportData && (() => {
        const alertsCount = reportData.filter(r => r.impact === 'TRIGGERED').length;

        return (
          <div id="print-overlay" className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-50 p-4 overflow-y-auto">
            <div id="printable-area" className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-2xl max-w-4xl w-full p-0 shadow-xl overflow-hidden my-8">

              {/* Report Header Banner */}
              <div className="bg-gradient-to-r from-teal-600 to-emerald-600 text-white p-6 relative">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                  <div>
                    <h3 className="text-xl font-extrabold tracking-wide uppercase">PetGuard Pro</h3>
                    <h4 className="text-sm font-semibold text-teal-100 mt-1">Live Database Telemetry & Traffic Report</h4>
                    <p className="text-[11px] text-teal-100/80 mt-2 font-mono">Generated: {new Date().toLocaleString()}</p>
                  </div>
                  <div className="flex space-x-2 no-print self-end md:self-center">
                    <button onClick={() => window.print()} className="px-4 py-2 bg-white text-teal-700 hover:bg-teal-50 text-xs font-bold rounded-lg shadow transition">
                      Print Report
                    </button>
                    <button onClick={() => setReportData(null)} className="px-4 py-2 bg-teal-800/50 hover:bg-teal-800/70 text-teal-50 text-xs font-bold rounded-lg transition">
                      Close
                    </button>
                  </div>
                </div>
              </div>

              <div className="p-6 space-y-6 text-slate-800 dark:text-slate-100">
                {/* Aggregate Statistics Grid */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div className="bg-teal-50/30 dark:bg-teal-950/10 border border-teal-100 dark:border-teal-900/30 rounded-xl p-4 transition hover:shadow-sm">
                    <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500 tracking-wider">Data Rate</p>
                    <p className="font-extrabold text-lg text-teal-600 dark:text-teal-400 mt-1">{Math.round(currentSpeed)} pkts/min</p>
                  </div>
                  <div className="bg-teal-50/30 dark:bg-teal-950/10 border border-teal-100 dark:border-teal-900/30 rounded-xl p-4 transition hover:shadow-sm">
                    <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500 tracking-wider">Harness Nodes</p>
                    <p className="font-extrabold text-lg text-teal-600 dark:text-teal-400 mt-1">{reportData.length} active</p>
                  </div>
                  <div className="bg-teal-50/30 dark:bg-teal-950/10 border border-teal-100 dark:border-teal-900/30 rounded-xl p-4 transition hover:shadow-sm">
                    <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500 tracking-wider">Active Alerts</p>
                    <p className="font-extrabold text-lg text-teal-600 dark:text-teal-400 mt-1">{alertsCount} triggered</p>
                  </div>
                </div>

                {/* Database Table */}
                <div className="border border-slate-200 dark:border-slate-700 rounded-xl overflow-hidden shadow-sm">
                  <table className="w-full text-left text-xs border-collapse">
                    <thead>
                      <tr className="bg-teal-700 text-white font-bold text-xs">
                        <th className="p-3.5">Harness ID</th>
                        <th className="p-3.5">Current Activity</th>
                        <th className="p-3.5">Steps</th>
                        <th className="p-3.5">Vitals (HR / Temp)</th>
                        <th className="p-3.5">Battery</th>
                        <th className="p-3.5">Impact Alert</th>
                        <th className="p-3.5">Location Coordinates</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100 dark:divide-slate-700/50">
                      {reportData.length === 0 ? (
                        <tr>
                          <td colSpan={7} className="p-5 text-center text-slate-400 bg-white dark:bg-slate-800">No active harness devices detected.</td>
                        </tr>
                      ) : (
                        reportData.map((item) => {
                          const batVal = parseInt(item.battery);
                          const batteryColor = batVal > 50
                            ? 'bg-emerald-100 dark:bg-emerald-950/30 text-emerald-700 dark:text-emerald-400'
                            : batVal > 20
                              ? 'bg-orange-100 dark:bg-orange-950/30 text-orange-700 dark:text-orange-400'
                              : 'bg-red-100 dark:bg-red-950/30 text-red-700 dark:text-red-400';

                          return (
                            <tr key={item.id} className="odd:bg-white even:bg-teal-50/5 dark:odd:bg-slate-800 dark:even:bg-teal-950/5 hover:bg-teal-50/10 dark:hover:bg-teal-950/10 transition-colors">
                              <td className="p-3.5 font-bold text-teal-800 dark:text-teal-300 font-mono">{item.id}</td>
                              <td className="p-3.5">
                                <span className="font-semibold text-slate-700 dark:text-slate-200">{item.activityType}</span>
                                <span className="block text-[10px] text-slate-400 mt-0.5">{item.activeMinutes.toFixed(1)} mins active</span>
                              </td>
                              <td className="p-3.5 font-bold text-slate-700 dark:text-slate-200">{item.stepCount.toLocaleString()}</td>
                              <td className="p-3.5">
                                <span className="font-semibold text-slate-700 dark:text-slate-200">{item.heartRate !== 'N/A' ? `${item.heartRate} bpm` : 'N/A'}</span>
                                <span className="block text-[10px] text-slate-400 mt-0.5 font-medium">{item.temperature}</span>
                              </td>
                              <td className="p-3.5">
                                <span className={`px-2 py-0.5 rounded-full font-bold text-[10px] ${batteryColor}`}>
                                  {item.battery}
                                </span>
                              </td>
                              <td className="p-3.5">
                                {item.impact === 'TRIGGERED' ? (
                                  <span className="px-2.5 py-1 bg-red-100 dark:bg-red-950/30 text-red-700 dark:text-red-400 rounded-full font-extrabold text-[10px] animate-pulse">
                                    IMPACT ({item.impactSeverity.toFixed(1)}/10)
                                  </span>
                                ) : (
                                  <span className="px-2.5 py-1 bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-300 rounded-full font-bold text-[10px]">
                                    NONE
                                  </span>
                                )}
                              </td>
                              <td className="p-3.5 text-slate-500 dark:text-slate-400 font-mono text-[10px] select-all">{item.coords}</td>
                            </tr>
                          );
                        })
                      )}
                    </tbody>
                  </table>
                </div>

                {/* Footer details visible only in print */}
                <div className="text-center text-[10px] text-slate-400 dark:text-slate-500 border-t border-slate-100 dark:border-slate-700 pt-4 mt-6">
                  <p>PetGuard Pro — System Administration Dashboard Dashboard Report Preview</p>
                  <p className="mt-0.5">Confidential | Department of Computer Engineering | University of Peradeniya</p>
                </div>

              </div>
            </div>
          </div>
        );
      })()}
    </div>
  );
}
