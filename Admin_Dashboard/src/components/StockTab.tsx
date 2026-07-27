import React, { useState, useEffect } from 'react';
import { collection, doc, setDoc, getDoc, deleteDoc, query, orderBy, onSnapshot } from 'firebase/firestore';
import { firestore } from '../firebase';
import { Package, Cpu, PlusCircle, Trash2, Search, Filter, ShieldAlert, CheckCircle2 } from 'lucide-react';

interface StockItem {
  id: string; // Document ID (Harness/Device Serial Number)
  type: 'harness' | 'device';
  model: string;
  status: 'available' | 'assigned' | 'faulty' | 'maintenance';
  addedAt: any;
  size?: string;
  color?: string;
  macAddress?: string;
  firmwareVersion?: string;
}

export default function StockTab() {
  const [stock, setStock] = useState<StockItem[]>([]);
  const [loading, setLoading] = useState(true);

  // Form State
  const [serialNumber, setSerialNumber] = useState('');
  const [type, setType] = useState<'harness' | 'device'>('harness');
  const [model, setModel] = useState('');
  const [status, setStatus] = useState<'available' | 'assigned' | 'faulty' | 'maintenance'>('available');
  
  // Dynamic metadata states
  const [size, setSize] = useState<'Small' | 'Medium' | 'Large'>('Medium');
  const [color, setColor] = useState('');
  const [macAddress, setMacAddress] = useState('');
  const [firmwareVersion, setFirmwareVersion] = useState('');

  const [formError, setFormError] = useState<string | null>(null);
  const [formSuccess, setFormSuccess] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  // Filters State
  const [searchQuery, setSearchQuery] = useState('');
  const [filterType, setFilterType] = useState<'all' | 'harness' | 'device'>('all');
  const [filterStatus, setFilterStatus] = useState<'all' | 'available' | 'assigned' | 'faulty' | 'maintenance'>('all');

  // Load stock list in real time
  useEffect(() => {
    const q = query(collection(firestore, 'stock'), orderBy('addedAt', 'desc'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const items: StockItem[] = [];
      snapshot.forEach((doc) => {
        items.push({ id: doc.id, ...doc.data() } as StockItem);
      });
      setStock(items);
      setLoading(false);
    }, (error) => {
      console.error("Firestore listening error: ", error);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const handleAddStock = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    setFormSuccess(null);

    const formattedSerial = serialNumber.trim().toUpperCase();
    if (!formattedSerial) {
      setFormError('Please enter a unique Serial Number/ID.');
      return;
    }
    if (!model.trim()) {
      setFormError('Please enter the hardware model description.');
      return;
    }

    setActionLoading(true);

    try {
      // 1. Check if the serial number already exists in stock
      const docRef = doc(firestore, 'stock', formattedSerial);
      const docSnap = await getDoc(docRef);
      if (docSnap.exists()) {
        setFormError(`Stock item with Serial ID "${formattedSerial}" already exists.`);
        setActionLoading(false);
        return;
      }

      // 2. Prepare dynamic metadata based on type
      const stockData: any = {
        type,
        model: model.trim(),
        status,
        addedAt: new Date(),
      };

      if (type === 'harness') {
        stockData.size = size;
        stockData.color = color.trim() || 'Default';
      } else {
        stockData.macAddress = macAddress.trim().toUpperCase() || 'N/A';
        stockData.firmwareVersion = firmwareVersion.trim() || 'v1.0.0';
      }

      // 3. Save to Firestore
      await setDoc(docRef, stockData);

      // 4. Reset Form Fields
      setSerialNumber('');
      setModel('');
      setColor('');
      setMacAddress('');
      setFirmwareVersion('');
      setStatus('available');
      setFormSuccess(`Successfully registered ${type === 'harness' ? 'harness' : 'device'} stock item "${formattedSerial}"!`);

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
    if (!window.confirm(`Are you sure you want to delete stock item ${id}?`)) {
      return;
    }
    try {
      await deleteDoc(doc(firestore, 'stock', id));
    } catch (err) {
      console.error(err);
      alert('Failed to delete item from stock.');
    }
  };

  // Filter logic
  const filteredStock = stock.filter((item) => {
    const matchesSearch = item.id.toLowerCase().includes(searchQuery.toLowerCase()) || 
                          item.model.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesType = filterType === 'all' || item.type === filterType;
    const matchesStatus = filterStatus === 'all' || item.status === filterStatus;
    return matchesSearch && matchesType && matchesStatus;
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
        <p className="text-sm text-slate-500 dark:text-slate-400">Register hardware harnesses and Telemetry Node modules</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Registration Form Panel */}
        <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-5 shadow-sm space-y-4">
          <div className="flex items-center space-x-2.5 pb-3 border-b border-slate-100 dark:border-slate-800">
            <div className="p-2 bg-teal-100 dark:bg-teal-950/30 text-teal-600 dark:text-teal-400 rounded-lg">
              <PlusCircle className="w-5 h-5" />
            </div>
            <h3 className="font-extrabold text-slate-800 dark:text-slate-100 text-sm uppercase tracking-wider">Register New Item</h3>
          </div>

          <form onSubmit={handleAddStock} className="space-y-4 text-xs">
            {/* Stock Type Toggle */}
            <div className="space-y-1.5">
              <label className="text-slate-400 font-bold block mb-1">Item Category</label>
              <div className="grid grid-cols-2 gap-2 bg-slate-50 dark:bg-slate-950 p-1.5 rounded-xl border border-slate-200/60 dark:border-slate-800/80">
                <button
                  type="button"
                  onClick={() => setType('harness')}
                  className={`py-2 rounded-lg font-bold transition flex items-center justify-center space-x-2 ${
                    type === 'harness'
                      ? 'bg-teal-600 text-white shadow-sm'
                      : 'text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900'
                  }`}
                >
                  <Package className="w-3.5 h-3.5" />
                  <span>Harness</span>
                </button>
                <button
                  type="button"
                  onClick={() => setType('device')}
                  className={`py-2 rounded-lg font-bold transition flex items-center justify-center space-x-2 ${
                    type === 'device'
                      ? 'bg-teal-600 text-white shadow-sm'
                      : 'text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-900'
                  }`}
                >
                  <Cpu className="w-3.5 h-3.5" />
                  <span>Device (Node)</span>
                </button>
              </div>
            </div>

            {/* Serial Number input */}
            <div className="space-y-1">
              <label className="text-slate-400 font-bold block">Serial Number / Unique ID</label>
              <input
                type="text"
                placeholder="e.g. PG-HRN-0921"
                value={serialNumber}
                onChange={(e) => setSerialNumber(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
              />
            </div>

            {/* Model description input */}
            <div className="space-y-1">
              <label className="text-slate-400 font-bold block">Model Description</label>
              <input
                type="text"
                placeholder={type === 'harness' ? 'e.g. Elastic Comfort Mesh v2' : 'e.g. ESP32 GPS Telemetry Module'}
                value={model}
                onChange={(e) => setModel(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
              />
            </div>

            {/* Dynamic fields for Harness */}
            {type === 'harness' && (
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-slate-400 font-bold block">Harness Size</label>
                  <select
                    value={size}
                    onChange={(e: any) => setSize(e.target.value)}
                    className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200"
                  >
                    <option value="Small">Small</option>
                    <option value="Medium">Medium</option>
                    <option value="Large">Large</option>
                  </select>
                </div>
                <div className="space-y-1">
                  <label className="text-slate-400 font-bold block">Fabric Color</label>
                  <input
                    type="text"
                    placeholder="e.g. Teal"
                    value={color}
                    onChange={(e) => setColor(e.target.value)}
                    className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
                  />
                </div>
              </div>
            )}

            {/* Dynamic fields for Device */}
            {type === 'device' && (
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-slate-400 font-bold block">MAC Address</label>
                  <input
                    type="text"
                    placeholder="e.g. AA:BB:CC:11:22:33"
                    value={macAddress}
                    onChange={(e) => setMacAddress(e.target.value)}
                    className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-slate-400 font-bold block">Firmware Version</label>
                  <input
                    type="text"
                    placeholder="e.g. v1.1.2"
                    value={firmwareVersion}
                    onChange={(e) => setFirmwareVersion(e.target.value)}
                    className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
                  />
                </div>
              </div>
            )}

            {/* Initial Status */}
            <div className="space-y-1">
              <label className="text-slate-400 font-bold block">Initial Status</label>
              <select
                value={status}
                onChange={(e: any) => setStatus(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-lg p-2.5 outline-none text-slate-700 dark:text-slate-200"
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
              className="w-full py-2.5 bg-teal-600 hover:bg-teal-700 text-white rounded-lg font-bold transition flex items-center justify-center gap-1.5 disabled:opacity-50"
            >
              {actionLoading ? 'Saving...' : 'Add Stock Item'}
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
                placeholder="Search serial / model..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl py-2 pl-9 pr-4 text-xs outline-none text-slate-700 dark:text-slate-200 focus:border-teal-500 transition"
              />
            </div>

            {/* Category / Status Filters */}
            <div className="flex w-full sm:w-auto items-center gap-2">
              {/* Type Filter */}
              <div className="flex items-center space-x-1.5 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-2.5 py-1.5">
                <Filter className="w-3 h-3 text-slate-400" />
                <select
                  value={filterType}
                  onChange={(e: any) => setFilterType(e.target.value)}
                  className="bg-transparent text-[11px] font-semibold text-slate-600 dark:text-slate-350 outline-none"
                >
                  <option value="all">All Types</option>
                  <option value="harness">Harnesses Only</option>
                  <option value="device">Devices Only</option>
                </select>
              </div>

              {/* Status Filter */}
              <div className="flex items-center space-x-1.5 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-2.5 py-1.5">
                <Filter className="w-3 h-3 text-slate-400" />
                <select
                  value={filterStatus}
                  onChange={(e: any) => setFilterStatus(e.target.value)}
                  className="bg-transparent text-[11px] font-semibold text-slate-600 dark:text-slate-350 outline-none"
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
                <div className="p-3.5 bg-slate-100 dark:bg-slate-950 text-slate-400 dark:text-slate-655 rounded-2xl">
                  <Package className="w-7 h-7" />
                </div>
                <h4 className="font-bold text-slate-700 dark:text-slate-350 text-sm">No inventory items matched.</h4>
                <p className="text-slate-450 dark:text-slate-500 text-xs">Add new stock records in the left panel.</p>
              </div>
            ) : (
              <table className="w-full text-left text-[11px] border-collapse">
                <thead>
                  <tr className="border-b border-slate-100 dark:border-slate-850 text-slate-400 dark:text-slate-500 tracking-wider">
                    <th className="py-2.5 px-3">Item Details</th>
                    <th className="py-2.5 px-3">Model</th>
                    <th className="py-2.5 px-3">Specifications</th>
                    <th className="py-2.5 px-3 text-center">Status</th>
                    <th className="py-2.5 px-3 text-center no-print">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-50 dark:divide-slate-850/50">
                  {filteredStock.map((item) => (
                    <tr key={item.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-855/10 transition-colors">
                      {/* Item category & Serial ID */}
                      <td className="py-3 px-3">
                        <div className="flex items-center space-x-2.5">
                          <div className={`p-1.5 rounded-lg ${
                            item.type === 'harness' 
                              ? 'bg-teal-50 dark:bg-teal-950/20 text-teal-600 dark:text-teal-400' 
                              : 'bg-indigo-50 dark:bg-indigo-950/20 text-indigo-650 dark:text-indigo-400'
                          }`}>
                            {item.type === 'harness' ? <Package className="w-3.5 h-3.5" /> : <Cpu className="w-3.5 h-3.5" />}
                          </div>
                          <div>
                            <span className="font-bold text-slate-700 dark:text-slate-200 font-mono tracking-tight text-xs block">{item.id}</span>
                            <span className="text-[10px] text-slate-400 dark:text-slate-500 capitalize">{item.type}</span>
                          </div>
                        </div>
                      </td>

                      {/* Model Description */}
                      <td className="py-3 px-3 font-semibold text-slate-600 dark:text-slate-350">
                        {item.model}
                      </td>

                      {/* Metadata specs based on category */}
                      <td className="py-3 px-3">
                        {item.type === 'harness' ? (
                          <div className="space-y-0.5 text-[10px]">
                            <p className="text-slate-700 dark:text-slate-300 font-medium">Size: <span className="font-bold">{item.size}</span></p>
                            <p className="text-slate-400 dark:text-slate-500">Color: <span className="font-semibold">{item.color}</span></p>
                          </div>
                        ) : (
                          <div className="space-y-0.5 text-[10px]">
                            <p className="text-slate-700 dark:text-slate-300 font-mono font-medium">MAC: {item.macAddress}</p>
                            <p className="text-slate-400 dark:text-slate-500">FW: <span className="font-semibold">{item.firmwareVersion}</span></p>
                          </div>
                        )}
                      </td>

                      {/* Status Badge */}
                      <td className="py-3 px-3 text-center">
                        <span className={`px-2 py-0.5 rounded-full border text-[9px] font-bold tracking-wider uppercase inline-block ${getStatusColor(item.status)}`}>
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
