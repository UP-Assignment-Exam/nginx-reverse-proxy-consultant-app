import mongoose, { Schema, Document } from 'mongoose';

export interface IConsultation extends Document {
  firstName: string;
  lastName: string;
  email: string;
  phoneNumber: string;
  createdAt: Date;
}

const ConsultationSchema: Schema = new Schema({
  firstName: { type: String, required: true },
  lastName: { type: String, required: true },
  email: { type: String, required: true },
  phoneNumber: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
});

export default mongoose.model<IConsultation>('Consultation', ConsultationSchema);
