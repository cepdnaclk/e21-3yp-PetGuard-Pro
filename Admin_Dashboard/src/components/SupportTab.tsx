import { useState, useEffect } from 'react';
import { collection, query, onSnapshot, doc, updateDoc, deleteDoc, orderBy } from 'firebase/firestore';
import { firestore } from '../firebase';
import { CheckCircle, Trash2, Clock, AlertCircle, Mail, Copy, ExternalLink, X } from 'lucide-react';

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

  // Email Composer Modal State
  const [emailModal, setEmailModal] = useState<{
    to: string;
    name: string;
    ticketId: string;
    message: string;
  } | null>(null);
  const [emailSubject, setEmailSubject] = useState('');
  const [emailBody, setEmailBody] = useState('');

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

  const openEmailModal = (ticket: Ticket) => {
    if (!ticket.email) return;
    const defaultSubject = `Re: PetGuard Pro Support Ticket #${ticket.id.substring(0, 6).toUpperCase()}`;
    const defaultBody = `Hi ${ticket.name || 'Owner'},\n\nRegarding your support ticket: "${ticket.message}"\n\n\n\nBest regards,\nPetGuard Pro Admin Team`;
    
    setEmailSubject(defaultSubject);
    setEmailBody(defaultBody);
    setEmailModal({
      to: ticket.email,
      name: ticket.name || 'Owner',
      ticketId: ticket.id,
      message: ticket.message || '',
    });
  };

  const sendViaGmail = () => {
    if (!emailModal) return;
    const url = `https://mail.google.com/mail/?view=cm&fs=1&to=${encodeURIComponent(emailModal.to)}&su=${encodeURIComponent(emailSubject)}&body=${encodeURIComponent(emailBody)}`;
    window.open(url, '_blank');
    setEmailModal(null);
  };

  const sendViaMailto = () => {
    if (!emailModal) return;
    const url = `mailto:${emailModal.to}?subject=${encodeURIComponent(emailSubject)}&body=${encodeURIComponent(emailBody)}`;
    window.location.href = url;
    setEmailModal(null);
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(emailBody);
    alert('Email body copied to clipboard!');
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
                      {ticket.email ? (
                        <button
                          onClick={() => openEmailModal(ticket)}
                          className="text-xs text-slate-400 dark:text-slate-500 hover:text-teal-600 dark:hover:text-teal-400 underline transition mt-0.5 inline-block text-left cursor-pointer"
                        >
                          {ticket.email}
                        </button>
                      ) : (
                        <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">No email provided</p>
                      )}
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

      {/* Email Composer Modal Overlay */}
      {emailModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-2xl max-w-lg w-full p-6 shadow-2xl flex flex-col space-y-4">
            
            {/* Header */}
            <div className="flex items-center justify-between border-b border-slate-150 dark:border-slate-700/50 pb-3">
              <div className="flex items-center space-x-2 text-teal-650 dark:text-teal-400">
                <Mail className="w-5 h-5" />
                <h3 className="text-lg font-bold text-slate-800 dark:text-slate-100">Compose Email to {emailModal.name}</h3>
              </div>
              <button
                type="button"
                onClick={() => setEmailModal(null)}
                className="p-1 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg text-slate-405 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-200 transition cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Recipient info (Readonly) */}
            <div className="text-xs text-slate-500 dark:text-slate-400">
              Sending to: <strong className="text-slate-750 dark:text-slate-200 font-semibold">{emailModal.to}</strong>
            </div>

            {/* Subject Input */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block">Subject:</label>
              <input
                type="text"
                value={emailSubject}
                onChange={(e) => setEmailSubject(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700/60 rounded-xl px-3 py-2 text-sm text-slate-800 dark:text-slate-100 outline-none focus:border-teal-500/50"
              />
            </div>

            {/* Message Body Input */}
            <div className="space-y-1.5 flex-1">
              <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block">Message Body:</label>
              <textarea
                rows={8}
                value={emailBody}
                onChange={(e) => setEmailBody(e.target.value)}
                className="w-full bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700/60 rounded-xl px-3 py-2 text-sm text-slate-850 dark:text-slate-100 outline-none focus:border-teal-500/50 resize-none font-sans"
              />
            </div>

            {/* Action Buttons */}
            <div className="flex flex-col sm:flex-row justify-between items-stretch sm:items-center gap-3 pt-3 border-t border-slate-150 dark:border-slate-700/50">
              <button
                type="button"
                onClick={copyToClipboard}
                className="flex items-center justify-center px-4 py-2 border border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-750 text-slate-600 dark:text-slate-350 text-xs font-bold rounded-xl transition cursor-pointer"
              >
                <Copy className="w-4 h-4 mr-2" />
                Copy Body
              </button>

              <div className="flex flex-col sm:flex-row gap-2">
                <button
                  type="button"
                  onClick={() => setEmailModal(null)}
                  className="px-4 py-2 bg-slate-100 hover:bg-slate-200 dark:bg-slate-700 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 text-xs font-bold rounded-xl transition cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={sendViaMailto}
                  className="flex items-center justify-center px-4 py-2 bg-slate-600 hover:bg-slate-700 text-white text-xs font-bold rounded-xl transition cursor-pointer"
                  title="Open default system mail client"
                >
                  <Mail className="w-4 h-4 mr-1.5" />
                  Local Mail App
                </button>
                <button
                  type="button"
                  onClick={sendViaGmail}
                  className="flex items-center justify-center px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white text-xs font-bold rounded-xl transition shadow-sm cursor-pointer"
                  title="Open Gmail Web Composer"
                >
                  <ExternalLink className="w-4 h-4 mr-1.5" />
                  Send via Gmail
                </button>
              </div>
            </div>

          </div>
        </div>
      )}
    </div>
  );
}
