import { useState, useEffect } from 'react';
import { collection, query, onSnapshot, doc, updateDoc, deleteDoc, where } from 'firebase/firestore';
import { ref, get, set } from 'firebase/database';
import { firestore, rtdb } from '../firebase';
import { Search, UserCheck, UserX, Trash2, PlusCircle, Info } from 'lucide-react';

interface User {
  id: string;
  name?: string;
  email?: string;
  phone?: string;
  pets?: number;
  status?: string;
  selectedPetId?: string;
}

export default function UsersTab() {
  const [users, setUsers] = useState<User[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);

  // Allocation State
  const [newPetId, setNewPetId] = useState('');
  const [allocating, setAllocating] = useState(false);
  const [allocatedIds, setAllocatedIds] = useState<string[]>([]);
  const [allocationError, setAllocationError] = useState<string | null>(null);
  
  // Custom states for pet display and reassignment toggling
  const [selectedUserPet, setSelectedUserPet] = useState<any | null>(null);
  const [showReassignForm, setShowReassignForm] = useState(false);

  // 1. Subscribe to Firestore users stream
  useEffect(() => {
    const q = query(collection(firestore, 'users'));
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const list = snapshot.docs
        .map((d) => ({ id: d.id, ...d.data() } as User))
        .filter((u) => u.status !== 'not_varified');
      setUsers(list);

      // Auto update selected user details if open
      if (selectedUser) {
        const updated = list.find((u) => u.id === selectedUser.id);
        if (updated) setSelectedUser(updated);
      }
    });

    return () => unsubscribe();
  }, [selectedUser]);

  // Reset showReassignForm and fetch pet details when selectedUser changes
  useEffect(() => {
    setShowReassignForm(false);
    if (!selectedUser) {
      setSelectedUserPet(null);
      return;
    }
    const q = query(
      collection(firestore, 'pets'),
      where('ownerUid', '==', selectedUser.id)
    );
    const unsubscribe = onSnapshot(q, (snapshot) => {
      if (!snapshot.empty) {
        setSelectedUserPet({ id: snapshot.docs[0].id, ...snapshot.docs[0].data() });
      } else {
        setSelectedUserPet(null);
      }
    }, (err) => {
      console.error('Error fetching pet details:', err);
      setSelectedUserPet(null);
    });

    return () => unsubscribe();
  }, [selectedUser?.id]);

  // 2. Fetch already allocated RTDB pet IDs
  useEffect(() => {
    const fetchPetIds = async () => {
      try {
        const snapshot = await get(ref(rtdb, 'pets'));
        if (snapshot.exists()) {
          setAllocatedIds(Object.keys(snapshot.val()));
        }
      } catch (e) {
        console.error(e);
      }
    };
    fetchPetIds();
  }, [allocating]);

  // Actions
  const updateStatus = async (user: User, newStatus: string) => {
    try {
      const userRef = doc(firestore, 'users', user.id);
      await updateDoc(userRef, { status: newStatus });
    } catch (e) {
      alert(`Error updating user status: ${e}`);
    }
  };

  const deleteUser = async (user: User) => {
    if (!window.confirm(`Are you sure you want to permanently delete user "${user.name || 'this user'}"?`)) {
      return;
    }
    try {
      const userRef = doc(firestore, 'users', user.id);
      await deleteDoc(userRef);
      if (selectedUser?.id === user.id) {
        setSelectedUser(null);
      }
    } catch (e) {
      alert(`Error deleting user: ${e}`);
    }
  };

  const handleAllocateHarness = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedUser) return;
    const petId = newPetId.trim();

    if (!petId) {
      setAllocationError('Harness Pet ID cannot be empty');
      return;
    }

    if (allocatedIds.includes(petId)) {
      setAllocationError('This Harness Pet ID already exists in the database. Choose a different one.');
      return;
    }

    if (petId === selectedUser.selectedPetId) {
      setAllocationError('This is already the current assigned Harness Pet ID.');
      return;
    }

    // Double confirmation prompt by asking the user to re-type the pet ID
    const confirmId = window.prompt(`Please re-type the Harness Pet ID "${petId}" to confirm assignment:`);
    if (confirmId === null) {
      return; // Cancelled
    }
    if (confirmId.trim() !== petId) {
      setAllocationError('Harness Pet ID confirmation did not match. Please try again.');
      return;
    }

    setAllocating(true);
    setAllocationError(null);

    try {
      // 1. Create default activity structure inside RTDB pets/$petId
      const petRef = ref(rtdb, `pets/${petId}`);
      await set(petRef, {
        activity: {
          current: {
            accelerometer: { x: 0, y: 0, z: 0 },
            active_minutes: 0,
            activity_type: 'idle',
            gyroscope: { x: 0, y: 0, z: 0 },
            impact_detected: false,
            impact_severity: 0,
            magnitude: 0,
            step_count: 0,
            timestamp: Date.now(),
          },
          history: {},
        },
        health: {},
        location: {},
      });

      // 2. Update Firestore user doc with selectedPetId
      const userRef = doc(firestore, 'users', selectedUser.id);
      await updateDoc(userRef, { selectedPetId: petId });

      // Reset
      setNewPetId('');
      setShowReassignForm(false);
      alert(`Harness ID "${petId}" successfully provisioned and linked to ${selectedUser.name}!`);
    } catch (err: any) {
      setAllocationError(err.message || 'An error occurred during allocation');
    } finally {
      setAllocating(false);
    }
  };

  const filteredUsers = users.filter((u) => {
    const name = (u.name || '').toLowerCase();
    const email = (u.email || '').toLowerCase();
    const phone = (u.phone || '').toLowerCase();
    const queryStr = searchTerm.toLowerCase();
    return name.includes(queryStr) || email.includes(queryStr) || phone.includes(queryStr);
  });

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Active':
        return 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950/30 dark:text-emerald-400 border-emerald-300/30';
      case 'Pending':
      case 'Inactive':
        return 'bg-amber-100 text-amber-700 dark:bg-amber-950/30 dark:text-amber-400 border-amber-300/30';
      case 'Blocked':
        return 'bg-rose-100 text-rose-700 dark:bg-rose-950/30 dark:text-rose-400 border-rose-300/30';
      default:
        return 'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-400 border-slate-300/30';
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold text-slate-800 dark:text-slate-100">User & Harness Management</h2>
        <p className="text-sm text-slate-500 dark:text-slate-400">Approve accounts, block users, and allocate telemetric hardware IDs</p>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6 items-start">
        {/* Left Side: Users list */}
        <div className="xl:col-span-2 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl shadow-sm overflow-hidden">
          {/* Search bar */}
          <div className="p-4 border-b border-slate-100 dark:border-slate-700/40 bg-slate-50/50 dark:bg-slate-900/10 flex items-center">
            <Search className="w-5 h-5 text-slate-400 mr-2" />
            <input
              type="text"
              placeholder="Search by name, email, or phone..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="bg-transparent text-sm w-full outline-none text-slate-700 dark:text-slate-200 placeholder-slate-400"
            />
          </div>

          {/* Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-sm">
              <thead>
                <tr className="bg-slate-50 dark:bg-slate-900/35 text-slate-400 font-semibold border-b border-slate-100 dark:border-slate-700/40">
                  <th className="p-4">Owner Name</th>
                  <th className="p-4">Email / Phone</th>
                  <th className="p-4">Status</th>
                  <th className="p-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredUsers.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="p-8 text-center text-slate-400 dark:text-slate-500">No active accounts matching criteria.</td>
                  </tr>
                ) : (
                  filteredUsers.map((u) => (
                    <tr
                      key={u.id}
                      onClick={() => setSelectedUser(u)}
                      className={`border-b border-slate-100 dark:border-slate-700/40 hover:bg-slate-50/50 dark:hover:bg-slate-800/30 cursor-pointer transition ${selectedUser?.id === u.id ? 'bg-slate-50/80 dark:bg-slate-800/50' : ''}`}
                    >
                      <td className="p-4">
                        <div className="font-semibold text-slate-800 dark:text-slate-100">{u.name || 'Unknown'}</div>
                        <div className="text-xs text-slate-400 dark:text-slate-500">UID: {u.id.substring(0, 10)}...</div>
                      </td>
                      <td className="p-4">
                        <div className="text-slate-700 dark:text-slate-300">{u.email || 'N/A'}</div>
                        <div className="text-xs text-slate-400 dark:text-slate-500">{u.phone || 'N/A'}</div>
                      </td>
                      <td className="p-4">
                        <span className={`inline-block border text-[10px] font-bold px-2 py-0.5 rounded-full ${getStatusColor(u.status || 'Pending')}`}>
                          {(u.status || 'Pending').toUpperCase()}
                        </span>
                      </td>
                      <td className="p-4 text-right space-x-1" onClick={(e) => e.stopPropagation()}>
                        {u.status !== 'Active' && (
                          <button
                            onClick={() => updateStatus(u, 'Active')}
                            title="Approve User"
                            className="p-1.5 text-emerald-600 hover:bg-emerald-50 dark:hover:bg-emerald-950/20 rounded-lg transition"
                          >
                            <UserCheck className="w-4 h-4" />
                          </button>
                        )}
                        {u.status !== 'Blocked' && (
                          <button
                            onClick={() => updateStatus(u, 'Blocked')}
                            title="Block User"
                            className="p-1.5 text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-950/20 rounded-lg transition"
                          >
                            <UserX className="w-4 h-4" />
                          </button>
                        )}
                        <button
                          onClick={() => deleteUser(u)}
                          title="Delete User"
                          className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-950/20 rounded-lg transition"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Right Side: Detail Drawer / Allocation Panel */}
        <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700/50 rounded-2xl p-5 shadow-sm space-y-5">
          {selectedUser ? (
            <>
              <div className="border-b border-slate-100 dark:border-slate-700/40 pb-4">
                <h3 className="font-bold text-slate-800 dark:text-slate-100 text-lg">{selectedUser.name || 'Owner Profile'}</h3>
                <span className="text-xs text-slate-400 dark:text-slate-500">Document ID: {selectedUser.id}</span>
              </div>

              {/* Details List */}
              <div className="space-y-3 text-sm">
                <div className="flex justify-between">
                  <span className="text-slate-400 dark:text-slate-500">Contact Number:</span>
                  <span className="font-semibold text-slate-700 dark:text-slate-200">{selectedUser.phone || 'N/A'}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400 dark:text-slate-500">Email Address:</span>
                  <span className="font-semibold text-slate-700 dark:text-slate-200">{selectedUser.email || 'N/A'}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400 dark:text-slate-500">Account status:</span>
                  <span className={`text-xs font-bold px-2 py-0.5 border rounded-full ${getStatusColor(selectedUser.status || 'Pending')}`}>
                    {(selectedUser.status || 'Pending').toUpperCase()}
                  </span>
                </div>
                <div className="flex justify-between items-start gap-2">
                  <span className="text-slate-400 dark:text-slate-500 shrink-0">Currently Assigned Harness:</span>
                  <span className="font-mono text-xs font-bold text-teal-600 dark:text-teal-400 break-all text-right">
                    {selectedUser.selectedPetId || 'None'}
                  </span>
                </div>
              </div>

              {/* Pet Details Section */}
              {selectedUserPet ? (
                <div className="border-t border-slate-100 dark:border-slate-700/40 pt-4 space-y-3">
                  <h4 className="font-bold text-slate-800 dark:text-slate-100 text-sm flex items-center">
                    <span className="w-2.5 h-2.5 rounded-full bg-teal-500 mr-2"></span>
                    Registered Pet Details
                  </h4>
                  <div className="grid grid-cols-2 gap-3 text-xs bg-slate-50 dark:bg-slate-900/40 p-3.5 rounded-xl border border-slate-100 dark:border-slate-800/60">
                    <div>
                      <span className="text-slate-400 dark:text-slate-500 block">Pet Name</span>
                      <span className="font-semibold text-slate-700 dark:text-slate-200">{selectedUserPet.petName || 'N/A'}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 dark:text-slate-500 block">Age Group</span>
                      <span className="font-semibold text-slate-700 dark:text-slate-200">{selectedUserPet.ageGroup || 'N/A'}</span>
                    </div>
                    <div className="mt-1">
                      <span className="text-slate-400 dark:text-slate-500 block">Harness Size (Dog Size)</span>
                      <span className="font-semibold text-slate-700 dark:text-slate-200">{selectedUserPet.size || 'N/A'}</span>
                    </div>
                    <div className="mt-1">
                      <span className="text-slate-400 dark:text-slate-500 block">Activity Level</span>
                      <span className="font-semibold text-slate-700 dark:text-slate-200">{selectedUserPet.activityLevel || 'N/A'}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 dark:text-slate-500 block">Coat Type</span>
                      <span className="font-semibold text-slate-700 dark:text-slate-200">{selectedUserPet.coatType || 'N/A'}</span>
                    </div>
                    <div className="mt-1">
                      <span className="text-slate-400 dark:text-slate-500 block">Flat Faced?</span>
                      <span className="font-semibold text-slate-700 dark:text-slate-200">{selectedUserPet.isFlatFaced || 'N/A'}</span>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="border-t border-slate-100 dark:border-slate-700/40 pt-4 text-xs text-slate-400 dark:text-slate-500 italic">
                  No registered pet profile found for this user yet.
                </div>
              )}

              {/* Harness Allocation / Reassignment Panel */}
              <div className="border-t border-slate-100 dark:border-slate-700/40 pt-4 space-y-4">
                {selectedUser.selectedPetId && !showReassignForm ? (
                  <div className="space-y-3 bg-slate-50 dark:bg-slate-900/40 p-4 rounded-xl border border-slate-100 dark:border-slate-800">
                    <div className="text-xs text-slate-500 dark:text-slate-400">
                      This user currently has a hardware harness assigned.
                    </div>
                    <div className="flex flex-col gap-1 bg-teal-50/50 dark:bg-teal-950/20 p-3 rounded-lg border border-teal-200/40 text-sm font-semibold">
                      <span className="text-teal-700 dark:text-teal-400 text-xs uppercase tracking-wider font-bold">Assigned Harness (Pet ID)</span>
                      <span className="font-mono text-teal-800 dark:text-teal-300 break-all select-all">{selectedUser.selectedPetId}</span>
                    </div>
                    <button
                      onClick={() => setShowReassignForm(true)}
                      className="w-full py-2 bg-slate-100 hover:bg-slate-200 dark:bg-slate-700 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-200 rounded-lg text-xs font-bold transition flex items-center justify-center border border-slate-200 dark:border-slate-600"
                    >
                      Change Harness (Assign another Pet ID)
                    </button>
                  </div>
                ) : (
                  <>
                    <h4 className="font-bold text-slate-800 dark:text-slate-100 text-sm flex items-center">
                      <PlusCircle className="w-4 h-4 mr-2 text-teal-500" />
                      {selectedUser.selectedPetId ? 'Change Harness Assignment' : 'Assign Telemetric Harness (PetID)'}
                    </h4>

                    <form onSubmit={handleAllocateHarness} className="space-y-3">
                      <div>
                        <label className="text-xs text-slate-400 dark:text-slate-500 block mb-1">New Unique Pet ID:</label>
                        <input
                          type="text"
                          placeholder=""
                          value={newPetId}
                          onChange={(e) => {
                            setNewPetId(e.target.value);
                            setAllocationError(null);
                          }}
                          className="w-full bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg p-2.5 text-sm outline-none text-slate-700 dark:text-slate-200"
                        />
                      </div>

                      {allocationError && (
                        <p className="text-xs text-rose-500 bg-rose-50 dark:bg-rose-950/20 border border-rose-500/20 p-2.5 rounded-lg">
                          {allocationError}
                        </p>
                      )}

                      <div className="flex gap-2">
                        {selectedUser.selectedPetId && (
                          <button
                            type="button"
                            onClick={() => {
                              setShowReassignForm(false);
                              setAllocationError(null);
                            }}
                            className="py-2.5 px-4 bg-slate-200 hover:bg-slate-300 text-slate-700 dark:bg-slate-700 dark:hover:bg-slate-600 dark:text-slate-200 rounded-lg text-sm font-bold transition"
                          >
                            Cancel
                          </button>
                        )}
                        <button
                          type="submit"
                          disabled={allocating}
                          className="flex-1 py-2.5 bg-primary hover:bg-teal-700 text-white rounded-lg text-sm font-bold transition flex items-center justify-center disabled:opacity-50"
                        >
                          {allocating ? 'Validating & Deploying...' : 'Approve Harness Assignment'}
                        </button>
                      </div>
                    </form>
                  </>
                )}

                {/* Pre-allocated list preview */}
                {allocatedIds.length > 0 && (
                  <div className="space-y-2 mt-4">
                    <span className="text-[10px] text-slate-400 dark:text-slate-500 block font-semibold uppercase tracking-wider">Already Assigned Pet IDs:</span>
                    <div className="flex flex-wrap gap-1.5 max-h-24 overflow-y-auto p-1 border border-slate-100 dark:border-slate-700/50 rounded-lg bg-slate-50/50 dark:bg-slate-900/10">
                      {allocatedIds.map((id) => (
                        <span key={id} className="text-[10px] px-2 py-0.5 bg-rose-50 border border-rose-200 text-rose-700 rounded-full dark:bg-rose-950/20 dark:border-rose-800/40 dark:text-rose-400">
                          {id}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </>
          ) : (
            <div className="h-64 flex flex-col items-center justify-center text-center text-slate-400 dark:text-slate-500 space-y-2">
              <Info className="w-8 h-8 opacity-40 text-teal-500" />
              <p className="text-sm">Select an owner account from the table to manage detailed telemetry assignments or change access configurations.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
