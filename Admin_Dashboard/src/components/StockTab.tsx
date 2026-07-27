import React, { useState, useEffect } from 'react';
import { collection, doc, setDoc, getDoc, deleteDoc, query, orderBy, onSnapshot } from 'firebase/firestore';
import { firestore } from '../firebase';
import { Package, PlusCircle, Trash2, Search, Filter, ShieldAlert, CheckCircle2 } from 'lucide-react';

interface HarnessStock {
  id: string; // Document ID (Device ID)
  deviceId: string;
  size: 'Small' | 'Medium' | 'Large';
  color: string;
  status: 'available' | 'assigned' | 'faulty' | 'maintenance';
  addedAt: any;
}

export default function StockTab() {
  const [stock, setStock] = useState<HarnessStock[]>([]);
  const [loading, setLoading] = useState(true);

  // Simplified Form State (Harness focus only)
  const [deviceId, setDeviceId] = useState('');
  const [size, setSize] = useState<'Small' | 'Medium' | 'Large'>('Medium');
  const [color, setColor] = useState('');
  const [status, setStatus] = useState<'available' | 'assigned' | 'faulty' | 'maintenance'>('available');

  const [formError, setFormError] = useState<string | null>(null);
  const [formSuccess, setFormSuccess] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  // Simplified Filtering States
  const [searchQuery, setSearchQuery] = useState('');
  const [filterSize, setFilterSize] = useState<'all' | 'Small' | 'Medium' | 'Large'>('all');
  const [filterStatus, setFilterStatus] = useState<'all' | 'available' | 'assigned' | 'faulty' | 'maintenance'>('all');

  // Load stock list in real time from firestore
  useEffect(() => {
    const q = query(collection(firestore, 'stock'), orderBy('addedAt', 'desc'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const items: HarnessStock[] = [];
      snapshot.forEach((doc) => {
        items.push({ id: doc.id, ...doc.data() } as HarnessStock);
      });
      setStock(items);
      setLoading(false);
    }, (error) => {
      console.error("Firestore listening error: ", error);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const handleAddHarness = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    setFormSuccess(null);

    const formattedDeviceId = deviceId.trim();
    if (!formattedDeviceId) {
      setFormError('Please enter a unique Device ID.');
      return;
    }
    if (!color.trim()) {
      setFormError('Please enter the harness fabric color.');
      return;
    }

    setActionLoading(true);

    try {
      // 1. Check if the device ID already exists in stock
      const docRef = doc(firestore, 'stock', formattedDeviceId);
      const docSnap = await getDoc(docRef);
      if (docSnap.exists()) {
        setFormError(`Harness with Device ID "${formattedDeviceId}" already exists in stock.`);
        setActionLoading(false);
        return;
      }

      // 2. Prepare stock data
      const harnessData = {
        deviceId: formattedDeviceId,
        size,
        color: color.trim(),
        status,
        addedAt: new Date(),
      };

      // 3. Save to Firestore
      await setDoc(docRef, harnessData);

      // 4. Reset Form Fields
      setDeviceId('');
      setColor('');
      setStatus('available');
      setFormSuccess(`Successfully registered Harness "${formattedDeviceId}" in stock!`);

      // Clear success notification after 4s
      setTimeout(() => setFormSuccess(null), 4000);
    } catch (err: any) {
      console.error(err);
      setFormError('Failed to register stock. Check connection or Firestore rules.');
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeleteItem = async (id: string) => {
    if (!window.confirm(`Are you sure you want to delete harness ${id} from stock inventory?`)) {
      return;
    }
    try {
      await deleteDoc(doc(firestore, 'stock', id));
    } catch (err) {
      console.error(err);
      alert('Failed to delete item from stock.');
    }
  };

  // Simplified filtering logic
  const filteredStock = stock.filter((item) => {
    const matchesSearch = item.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (item.color || '').toLowerCase().includes(searchQuery.toLowerCase());
    const matchesSize = filterSize === 'all' || item.size === filterSize;
    const matchesStatus = filterStatus === 'all' || item.status === filterStatus;
    return matchesSearch && matchesSize && matchesStatus;
  });

  const getStatusColor = (itemStatus: string) => {
    switch (itemStatus) {
      case 'available':
        return 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/30 dark:text-emerald-400 border-emerald-200/55';
      case 'assigned':
        return 'bg-blue-100 text-blue-700 dark:bg-blue-950/30 dark:text-blue-400 border-blue-200/55';
      case 'faulty':
        return 'bg-rose-100 text-rose-700 dark:bg-rose-950/30 dark:text-rose-400 border-rose-200/55 animate-pulse';
      case 'maintenance':
        return 'bg-amber-100 text-amber-700 dark:bg-amber-950/30 dark:text-amber-400 border-amber-200/55';
      default:
        return 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-350 border-slate-200';
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">Stock Inventory Desk</h2>
        <p className="text-sm text-slate-500 dark:text-slate-400">Add harnesses and track available hardware modules in stock</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Registration Form Panel */}
        <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-5 shadow-sm space-y-4">
          <div className="flex items-center space-x-2.5 pb-3 border-b border-slate-100 dark:border-slate-800">
            <div className="p-2 bg-teal-100 dark:bg-teal-950/30 text-teal-600 dark:text-teal-400 rounded-lg">
              <PlusCircle className="w-5 h-5" />
            </div>
            <h3 className="font-extrabold text-slate-800 dark:text-slate-100 text-sm uppercase tracking-wider">Register Harness</h3>
          </div>

          <form onSubmit={handleAddHarness} className="space-y-4 text-xs">
            {/* Device ID Input */}
            <div className="space-y-1">
              <label className="text-slate-400 dark:text-slate-500 font-bold block">Device ID (Hardware Path)</label>
              <input
                type="text"
                placeholder="Enter unique ID (e.g. pet02, PG-HRN-092)"
                value={deviceId}
                onChange={(e) => setDeviceId(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
              />
            </div>

            {/* Harness Size Selection */}
            <div className="space-y-1">
              <label className="text-slate-400 dark:text-slate-500 font-bold block">Harness Size</label>
              <select
                value={size}
                onChange={(e: any) => setSize(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
              >
                <option value="Small">Small</option>
                <option value="Medium">Medium</option>
                <option value="Large">Large</option>
              </select>
            </div>

            {/* Fabric Color Input */}
            <div className="space-y-1">
              <label className="text-slate-400 dark:text-slate-500 font-bold block">Fabric Color</label>
              <input
                type="text"
                placeholder="e.g. Crimson Red, Teal, Royal Blue"
                value={color}
                onChange={(e) => setColor(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
              />
            </div>

            {/* Initial Status */}
            <div className="space-y-1">
              <label className="text-slate-400 dark:text-slate-500 font-bold block">Initial Status</label>
              <select
                value={status}
                onChange={(e: any) => setStatus(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
              >
                <option value="available">Available</option>
                <option value="assigned">Assigned</option>
                <option value="faulty">Faulty</option>
                <option value="maintenance">Maintenance</option>
              </select>
            </div>

            {formError && (
              <div className="p-3 bg-rose-500/10 border border-rose-500/25 rounded-lg flex items-start space-x-2 text-rose-500">
                <ShieldAlert className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{formError}</span>
              </div>
            )}

            {formSuccess && (
              <div className="p-3 bg-emerald-500/10 border border-emerald-500/25 rounded-lg flex items-start space-x-2 text-emerald-500">
                <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
                <span>{formSuccess}</span>
              </div>
            )}

            <button
              type="submit"
              disabled={actionLoading}
              className="w-full py-2.5 bg-primary hover:bg-teal-700 text-white rounded-lg font-bold transition disabled:opacity-50"
            >
              {actionLoading ? 'Saving...' : 'Add Harness to Stock'}
            </button>
          </form>
        </div>

        {/* Directory View Table Panel */}
        <div className="lg:col-span-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-5 shadow-sm flex flex-col space-y-4">
          {/* Filtering Header controls */}
          <div className="flex flex-col sm:flex-row gap-3 justify-between items-center pb-3 border-b border-slate-100 dark:border-slate-800">
            {/* Search Box */}
            <div className="relative w-full sm:max-w-xs">
              <span className="absolute inset-y-0 left-0 pl-3 flex items-center text-slate-400">
                <Search className="w-3.5 h-3.5" />
              </span>
              <input
                type="text"
                placeholder="Search Device ID or Color..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl py-2 pl-9 pr-4 text-xs outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
              />
            </div>

            {/* Category / Status Filters */}
            <div className="flex w-full sm:w-auto items-center gap-2">
              {/* Size Filter */}
              <div className="flex items-center space-x-1.5 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-2.5 py-1.5">
                <Filter className="w-3 h-3 text-slate-400" />
                <select
                  value={filterSize}
                  onChange={(e: any) => setFilterSize(e.target.value)}
                  className="bg-transparent text-[11px] font-semibold text-slate-600 dark:text-slate-350 outline-none border-none"
                >
                  <option value="all">All Sizes</option>
                  <option value="Small">Small Only</option>
                  <option value="Medium">Medium Only</option>
                  <option value="Large">Large Only</option>
                </select>
              </div>

              {/* Status Filter */}
              <div className="flex items-center space-x-1.5 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-2.5 py-1.5">
                <Filter className="w-3 h-3 text-slate-400" />
                <select
                  value={filterStatus}
                  onChange={(e: any) => setFilterStatus(e.target.value)}
                  className="bg-transparent text-[11px] font-semibold text-slate-600 dark:text-slate-350 outline-none border-none"
                >
                  <option value="all">All Status</option>
                  <option value="available">Available</option>
                  <option value="assigned">Assigned</option>
                  <option value="faulty">Faulty</option>
                  <option value="maintenance">Maintenance</option>
                </select>
              </div>
            </div>
          </div>

          {/* Table Container */}
          <div className="flex-1 overflow-x-auto min-h-[300px]">
            {loading ? (
              <div className="flex items-center justify-center h-full py-12">
                <div className="w-8 h-8 border-4 border-teal-500 border-t-transparent rounded-full animate-spin"></div>
              </div>
            ) : filteredStock.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-16 text-center space-y-2">
                <div className="p-3.5 bg-slate-100 dark:bg-slate-955 text-slate-400 dark:text-slate-600 rounded-2xl">
                  <Package className="w-7 h-7" />
                </div>
                <h4 className="font-bold text-slate-700 dark:text-slate-300 text-sm">No harnesses matched.</h4>
                <p className="text-slate-400 dark:text-slate-500 text-xs">Add new stock records in the left panel.</p>
              </div>
            ) : (
              <table className="w-full text-left text-[11px] border-collapse">
                <thead>
                  <tr className="border-b border-slate-100 dark:border-slate-800 text-slate-400 dark:text-slate-500 tracking-wider uppercase">
                    <th className="py-2.5 px-3">Device ID</th>
                    <th className="py-2.5 px-3">Size</th>
                    <th className="py-2.5 px-3">Fabric Color</th>
                    <th className="py-2.5 px-3 text-center">Status</th>
                    <th className="py-2.5 px-3 text-center no-print">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-50 dark:divide-slate-800/50">
                  {filteredStock.map((item) => (
                    <tr key={item.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-800/10 transition-colors">
                      {/* Device ID */}
                      <td className="py-3 px-3">
                        <div className="flex items-center space-x-2.5">
                          <div className="p-1.5 rounded-lg bg-teal-50 dark:bg-teal-950/20 text-teal-600 dark:text-teal-400">
                            <Package className="w-3.5 h-3.5" />
                          </div>
                          <div>
                            <span className="font-bold text-slate-700 dark:text-slate-200 font-mono tracking-tight text-xs block">{item.deviceId}</span>
                          </div>
                        </div>
                      </td>

                      {/* Size */}
                      <td className="py-3 px-3 font-semibold text-slate-600 dark:text-slate-300">
                        {item.size}
                      </td>

                      {/* Color */}
                      <td className="py-3 px-3 font-semibold text-slate-600 dark:text-slate-300">
                        {item.color}
                      </td>

                      {/* Status Badge */}
                      <td className="py-3 px-3 text-center">
                        <span className={`px-2.5 py-0.5 rounded-full border text-[9px] font-bold tracking-wider uppercase inline-block ${getStatusColor(item.status)}`}>
                          {item.status}
                        </span>
                      </td>

                      {/* Delete option */}
                      <td className="py-3 px-3 text-center no-print">
                        <button
                          onClick={() => handleDeleteItem(item.id)}
                          className="p-1.5 text-rose-500/75 hover:text-rose-500 hover:bg-rose-500/10 rounded-lg transition"
                          title="Remove from inventory"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
