import { useState, useEffect } from 'react';
import { collection, query, onSnapshot, doc, updateDoc, deleteDoc, orderBy } from 'firebase/firestore';
import { firestore } from '../firebase';
import { CheckCircle, Trash2, Clock, AlertCircle } from 'lucide-react';

interface Ticket {
  id: string;
  name?: string;
  email?: string;
  message?: string;
  status?: string;
  timestamp?: any;
}

export default function SupportTab() {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [loading, setLoading] = useState(true);

  // Subscribe to support_tickets stream
  useEffect(() => {
    const q = query(collection(firestore, 'support_tickets'), orderBy('timestamp', 'desc'));
    const unsubscribe = onSnapshot(
      q,
      (snapshot) => {
        const list = snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as Ticket));
        setTickets(list);
        setLoading(false);
      },
      (error) => {
        console.error('Error loading tickets:', error);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, []);

  const toggleStatus = async (ticket: Ticket) => {
    const newStatus = ticket.status === 'Open' ? 'Resolved' : 'Open';
    try {
      const ticketRef = doc(firestore, 'support_tickets', ticket.id);
      await updateDoc(ticketRef, { status: newStatus });
    } catch (e) {
      alert(`Error toggling ticket status: ${e}`);
    }
  };

  const deleteTicket = async (ticket: Ticket) => {
    if (!window.confirm('Are you sure you want to permanently delete this support ticket?')) {
      return;
    }
    try {
      const ticketRef = doc(firestore, 'support_tickets', ticket.id);
      await deleteDoc(ticketRef);
    } catch (e) {
      alert(`Error deleting ticket: ${e}`);
    }
  };

  const formatTimestamp = (timestamp: any) => {
    if (!timestamp) return 'Just now';
    if (typeof timestamp.toDate === 'function') {
      return timestamp.toDate().toLocaleString();
    }
    const d = new Date(timestamp);
    return isNaN(d.getTime()) ? 'Just now' : d.toLocaleString();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">Customer Support Tickets</h2>
        <p className="text-sm text-slate-500 dark:text-slate-400">Manage owner requests, offline connection alerts, and system issues</p>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="w-8 h-8 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
        </div>
      ) : tickets.length === 0 ? (
        <div className="flex flex-col items-center justify-center p-12 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl text-center space-y-4">
          <AlertCircle className="w-12 h-12 text-slate-300 dark:text-slate-600" />
          <div>
            <h3 className="font-bold text-slate-700 dark:text-slate-200">No active tickets</h3>
            <p className="text-sm text-slate-400 dark:text-slate-500 mt-1">User support requests will appear here in real-time.</p>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {tickets.map((ticket) => {
            const isOpen = ticket.status === 'Open';
            return (
              <div
                key={ticket.id}
                className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl p-5 shadow-sm space-y-4 flex flex-col justify-between"
              >
                <div className="space-y-3">
                  <div className="flex items-start justify-between">
                    <div>
                      <h4 className="font-bold text-slate-800 dark:text-slate-100">{ticket.name || 'Anonymous Owner'}</h4>
                      <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">{ticket.email || 'No email provided'}</p>
                    </div>

                    {/* Status Badge */}
                    <span
                      className={`text-[10px] font-bold border px-2 py-0.5 rounded-full ${
                        isOpen
                          ? 'bg-rose-100 border-rose-300/30 text-rose-700 dark:bg-rose-950/20 dark:text-rose-400'
                          : 'bg-emerald-100 border-emerald-300/30 text-emerald-700 dark:bg-emerald-950/20 dark:text-emerald-400'
                      }`}
                    >
                      {(ticket.status || 'Open').toUpperCase()}
                    </span>
                  </div>

                  <p className="text-sm text-slate-600 dark:text-slate-300 leading-relaxed bg-slate-50/50 dark:bg-slate-900/10 p-3 rounded-xl border border-slate-100 dark:border-slate-700/30 whitespace-pre-line">
                    {ticket.message || 'No description provided.'}
                  </p>
                </div>

                <div className="border-t border-slate-100 dark:border-slate-700/30 pt-3 flex items-center justify-between text-xs text-slate-400 dark:text-slate-500">
                  <span className="flex items-center">
                    <Clock className="w-3.5 h-3.5 mr-1" />
                    {formatTimestamp(ticket.timestamp)}
                  </span>

                  <div className="flex space-x-2">
                    <button
                      onClick={() => toggleStatus(ticket)}
                      title={isOpen ? 'Mark as Resolved' : 'Re-open Ticket'}
                      className={`flex items-center px-3 py-1.5 rounded-lg font-bold border transition ${
                        isOpen
                          ? 'bg-emerald-50 border-emerald-500/10 hover:bg-emerald-100 text-emerald-700 dark:bg-emerald-950/20 dark:text-emerald-400'
                          : 'bg-orange-50 border-orange-500/10 hover:bg-orange-100 text-orange-700 dark:bg-orange-950/20 dark:text-orange-400'
                      }`}
                    >
                      <CheckCircle className="w-3.5 h-3.5 mr-1.5" />
                      {isOpen ? 'Resolve' : 'Re-open'}
                    </button>

                    <button
                      onClick={() => deleteTicket(ticket)}
                      title="Delete Ticket"
                      className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-950/20 rounded-lg border border-transparent transition"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
