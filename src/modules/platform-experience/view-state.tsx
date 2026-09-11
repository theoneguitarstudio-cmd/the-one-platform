"use client";
import { createContext, useContext, useMemo, useState, type Dispatch, type SetStateAction, type ReactNode } from "react";

type ViewState = {
  cancelledPreviews:string[]; setCancelledPreviews:Dispatch<SetStateAction<string[]>>;
  readNotificationIds:string[];setReadNotificationIds:Dispatch<SetStateAction<string[]>>;
};
const Context=createContext<ViewState|null>(null);
/** UI presentation only. No subscription, notification service, or entitlement state. */
export function ExperienceViewProvider({children}:{children:ReactNode}){
  const [cancelledPreviews,setCancelledPreviews]=useState<string[]>([]);
  const [readNotificationIds,setReadNotificationIds]=useState<string[]>([]);
  const value=useMemo(()=>({cancelledPreviews,setCancelledPreviews,readNotificationIds,setReadNotificationIds}),[cancelledPreviews,readNotificationIds]);
  return <Context.Provider value={value}>{children}</Context.Provider>;
}
export function useExperienceViewState(){const value=useContext(Context);if(!value)throw new Error("Local experience view provider required");return value;}
