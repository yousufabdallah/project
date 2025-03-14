import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface DriverSurveyModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export function DriverSurveyModal({ isOpen, onClose }: DriverSurveyModalProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [existingSurvey, setExistingSurvey] = useState<any>(null);
  const [form, setForm] = useState({
    fullName: '',
    tribe: '',
    age: '',
    carType: '',
    civilId: '',
    phoneNumber: ''
  });

  useEffect(() => {
    if (isOpen) {
      checkExistingSurvey();
    }
  }, [isOpen]);

  const checkExistingSurvey = async () => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) return;

      const { data, error } = await supabase
        .from('driver_surveys')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle(); // Changed from single() to maybeSingle()

      if (error && error.code !== 'PGRST116') throw error;
      if (data) {
        setExistingSurvey(data);
      }
    } catch (err: any) {
      console.error('Error checking survey:', err);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess('');

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('User not found');

      // Check if survey already exists
      const { data: existingSurveyData, error: existingError } = await supabase
        .from('driver_surveys')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

      if (existingError && existingError.code !== 'PGRST116') throw existingError;
      if (existingSurveyData) {
        throw new Error('لقد قمت بتقديم طلب مسبقاً');
      }

      // Insert new survey
      const { error } = await supabase
        .from('driver_surveys')
        .insert({
          user_id: user.id,
          full_name: form.fullName,
          tribe: form.tribe,
          age: parseInt(form.age),
          car_type: form.carType,
          civil_id: form.civilId,
          phone_number: form.phoneNumber
        });

      if (error) throw error;

      // Check if driver permission already exists
      const { data: existingPermission, error: permissionCheckError } = await supabase
        .from('driver_permissions')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

      if (permissionCheckError && permissionCheckError.code !== 'PGRST116') throw permissionCheckError;

      // Only create driver permission if it doesn't exist
      if (!existingPermission) {
        const { error: permissionError } = await supabase
          .from('driver_permissions')
          .insert({
            user_id: user.id,
            is_approved: false
          });

        if (permissionError) throw permissionError;
      }

      setSuccess('تم تقديم طلبك بنجاح وهو قيد المراجعة');
      setTimeout(() => {
        onClose();
        setSuccess('');
      }, 2000);
    } catch (err: any) {
      console.error('Error submitting survey:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  if (existingSurvey) {
    return (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
        <div className="bg-white rounded-lg p-8 max-w-md w-full relative">
          <button
            onClick={onClose}
            className="absolute top-4 right-4 text-gray-500 hover:text-gray-700"
          >
            <X size={24} />
          </button>
          <h2 className="text-2xl font-bold mb-6 text-center">حالة الطلب</h2>
          <div className="text-center">
            <p className="mb-4">
              {existingSurvey.status === 'pending' && 'طلبك قيد المراجعة'}
              {existingSurvey.status === 'approved' && 'تم قبول طلبك'}
              {existingSurvey.status === 'rejected' && 'تم رفض طلبك'}
            </p>
            <button
              onClick={onClose}
              className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
            >
              حسناً
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg p-8 max-w-md w-full relative">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-500 hover:text-gray-700"
        >
          <X size={24} />
        </button>
        <h2 className="text-2xl font-bold mb-6 text-center">تسجيل كسائق</h2>
        
        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
            {error}
          </div>
        )}
        
        {success && (
          <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4">
            {success}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-gray-700 mb-2">الاسم الكامل</label>
            <input
              type="text"
              value={form.fullName}
              onChange={(e) => setForm({ ...form, fullName: e.target.value })}
              className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>
          
          <div>
            <label className="block text-gray-700 mb-2">القبيلة</label>
            <input
              type="text"
              value={form.tribe}
              onChange={(e) => setForm({ ...form, tribe: e.target.value })}
              className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>
          
          <div>
            <label className="block text-gray-700 mb-2">العمر</label>
            <input
              type="number"
              value={form.age}
              onChange={(e) => setForm({ ...form, age: e.target.value })}
              className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
              required
              min="18"
            />
          </div>
          
          <div>
            <label className="block text-gray-700 mb-2">نوع السيارة</label>
            <input
              type="text"
              value={form.carType}
              onChange={(e) => setForm({ ...form, carType: e.target.value })}
              className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>
          
          <div>
            <label className="block text-gray-700 mb-2">الرقم المدني</label>
            <input
              type="text"
              value={form.civilId}
              onChange={(e) => setForm({ ...form, civilId: e.target.value })}
              className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>
          
          <div>
            <label className="block text-gray-700 mb-2">رقم الهاتف</label>
            <input
              type="tel"
              value={form.phoneNumber}
              onChange={(e) => setForm({ ...form, phoneNumber: e.target.value })}
              className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
              required
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'جاري التسجيل...' : 'تقديم الطلب'}
          </button>
        </form>
      </div>
    </div>
  );
}